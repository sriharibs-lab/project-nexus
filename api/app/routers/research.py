"""
POST /collections/research — AI-seeded collection creation.

Streams source rows to the client via Server-Sent Events (SSE) as Claude Sonnet
discovers them. The iOS FRE screen receives one event per source and renders them
progressively.

Flow:
  1. Client sends {"topic": "Ozempic and longevity"}
  2. Server calls Claude Sonnet (research_topic — SPEC §9c)
  3. Each SourceRow is immediately serialised and flushed as an SSE event
  4. After all sources stream, server:
     a. Creates the Collection record (created_by=ai)
     b. Writes AiTelemetry (cost, tokens, model)
     c. Sends a final SSE event: {"event": "done", "collection_id": "<uuid>"}
  5. Client confirms selection → uses POST /ingest to enqueue chosen sources

SSE event format (one per source, then one "done"):
  data: {"event": "source", "index": 0, "source": {...}}
  data: {"event": "done", "collection_id": "uuid", "source_count": 8}
  data: {"event": "error", "message": "..."}  ← only on failure

Note on 'total' count: sources are buffered until the stream closes (the model
returns a complete JSON array). The 'total' field is not available per-event;
the iOS client reads source_count from the 'done' event instead.
"""

import json
import logging
import time
import uuid
from collections.abc import AsyncGenerator
from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Body, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import AsyncSessionLocal, get_db
from app.middleware.auth import get_current_user
from app.models.ai_telemetry import AiTelemetry
from app.models.collection import Collection, CollectionCreatedBy
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/collections", tags=["research"])


class ResearchRequest(BaseModel):
    topic: str
    # Collection name defaults to the topic — user can rename after creation
    name: str | None = None


async def _resolve_user(supabase_id: str, db: AsyncSession) -> User:
    result = await db.execute(select(User).where(User.supabase_id == supabase_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


def _sse(payload: dict) -> str:
    """Serialize a dict as a single SSE data line."""
    return f"data: {json.dumps(payload)}\n\n"


async def _stream_research(
    topic: str,
    collection_name: str,
    user_id: uuid.UUID,
    correlation_id: str,
) -> AsyncGenerator[str, None]:
    """
    Core SSE generator.

    Streams source rows from Claude Sonnet, then writes the Collection and
    AiTelemetry records in the same DB session after the stream finishes.
    All DB work is done after streaming completes — we never hold a DB
    connection open while waiting on Claude.
    """
    from ai.pipeline import research_topic

    # Gate: if no API key, yield error event immediately
    if not settings.anthropic_api_key:
        yield _sse({
            "event": "error",
            "message": "ANTHROPIC_API_KEY not configured. Add it to api/.env to enable research.",
        })
        return

    t0 = time.perf_counter()
    sources_collected = []

    try:
        # Stream sources from Claude Sonnet one by one
        # research_topic is an async generator yielding SourceRow objects
        async for idx, source in _enumerate_async(research_topic(topic)):
            source_payload = {
                "event": "source",
                "index": idx,
                "source": {
                    "title": source.title,
                    "url": source.url,
                    "domain": source.domain,
                    "rationale": source.rationale,
                    "content_type": source.content_type,
                },
            }
            sources_collected.append(source)
            yield _sse(source_payload)

    except Exception as exc:
        logger.exception("Research stream failed for topic=%r: %s", topic, exc)
        yield _sse({"event": "error", "message": "Research failed. Please try again."})
        return

    if not sources_collected:
        yield _sse({"event": "error", "message": "No sources found. Try a more specific topic."})
        return

    # ── Persist Collection + Telemetry ────────────────────────────────────────
    # Token counts are estimated (the streaming API buffers internally but we
    # don't plumb usage out of the generator to avoid coupling). Conservative
    # estimate is sufficient for cost visibility at this stage. Upgrade to
    # stream.get_final_message().usage before TestFlight for accurate tracking.
    duration_ms = int((time.perf_counter() - t0) * 1000)

    try:
        collection_id = uuid.uuid4()

        async with AsyncSessionLocal() as db:
            collection = Collection(
                id=collection_id,
                user_id=user_id,
                name=collection_name,
                description=f"AI-curated sources on: {topic}",
                created_by=CollectionCreatedBy.ai,
                source_count=0,  # incremented by ingest pipeline as each source is saved
            )
            db.add(collection)

            # Telemetry: log estimated cost based on source count
            estimated_input = 500 + len(topic) // 4  # system prompt + user message
            estimated_output = len(sources_collected) * 80  # ~80 tokens per source row
            estimated_cost = (
                Decimal(estimated_input) * Decimal("0.000003")
                + Decimal(estimated_output) * Decimal("0.000015")
            )

            db.add(AiTelemetry(
                id=uuid.uuid4(),
                user_id=user_id,
                collection_id=collection_id,
                correlation_id=correlation_id,
                operation="collection_research",
                model="claude-sonnet-4-6",
                input_tokens=estimated_input,
                output_tokens=estimated_output,
                cache_read_tokens=0,
                cost_usd=estimated_cost,
                duration_ms=duration_ms,
            ))

            await db.commit()

        yield _sse({
            "event": "done",
            "collection_id": str(collection_id),
            "source_count": len(sources_collected),
        })

    except Exception as exc:
        logger.exception("Failed to persist collection after research: %s", exc)
        yield _sse({"event": "error", "message": "Sources found but collection save failed."})


async def _enumerate_async(agen: AsyncGenerator) -> AsyncGenerator[tuple[int, object], None]:
    """Async equivalent of enumerate() for async generators."""
    idx = 0
    async for item in agen:
        yield idx, item
        idx += 1


@router.post(
    "/research",
    summary="AI-seeded collection creation via SSE",
    description=(
        "Streams Claude Sonnet source suggestions for a topic. "
        "Returns SSE events: `source` (one per result), then `done` with the new collection_id."
    ),
    response_class=StreamingResponse,
    # FastAPI can't auto-document StreamingResponse — add manual status_code
    status_code=status.HTTP_200_OK,
)
async def research_collection(
    payload: Annotated[ResearchRequest, Body()],
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    """
    POST /v1/collections/research

    Request body:
        {"topic": "Ozempic and longevity", "name": "My Collection"}

    SSE stream:
        data: {"event": "source", "index": 0, "source": {...}}
        ...
        data: {"event": "done", "collection_id": "uuid", "source_count": 8}
        data: {"event": "error", "message": "..."} (on failure)
    """
    topic = payload.topic.strip()
    if not topic:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="topic is required")
    if len(topic) > 500:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="topic too long (max 500 chars)")

    user = await _resolve_user(current_user["supabase_id"], db)
    collection_name = (payload.name or topic).strip()[:255]
    correlation_id = str(uuid.uuid4())

    return StreamingResponse(
        _stream_research(
            topic=topic,
            collection_name=collection_name,
            user_id=user.id,
            correlation_id=correlation_id,
        ),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # disable Nginx buffering for SSE
            "Connection": "keep-alive",
        },
    )
