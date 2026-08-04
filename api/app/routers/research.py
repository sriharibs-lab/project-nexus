"""
POST /collections/research — AI-seeded collection creation.

Streams source rows to the client via Server-Sent Events (SSE) as Claude Sonnet
discovers them. The iOS FRE screen receives one event per source and renders them
progressively.

Flow:
  1. Client sends {"topic": "Ozempic and longevity"}
  2. Server calls Claude Sonnet (research_topic_with_usage — SPEC §9c)
  3. A 'searching' heartbeat is yielded immediately (iOS loading screen)
  4. After Claude returns, each SourceRow is yielded as an SSE 'source' event
  5. Server persists the Collection record (with framing_paragraph)
     and writes AiTelemetry with REAL token counts
  6. Sends a final SSE event: {"event": "done", "collection_id": "<uuid>"}
  7. Client confirms selection → uses POST /ingest to enqueue chosen sources

SSE event format:
  data: {"event": "searching", "topic": "..."}   ← immediate heartbeat
  data: {"event": "source", "index": 0, "source": {...}}
  data: {"event": "done", "collection_id": "uuid", "source_count": 8}
  data: {"event": "error", "message": "..."}  ← only on failure
"""

import asyncio
import json
import logging
import time
import uuid
from collections.abc import AsyncGenerator
from decimal import Decimal
from typing import Annotated

import httpx

from fastapi import APIRouter, Body, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import AsyncSessionLocal, get_db
from app.middleware.auth import get_current_user
from app.models.ai_telemetry import AiTelemetry
from app.models.collection import Collection
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


_URL_CHECK_TIMEOUT = 6.0
_URL_CHECK_UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0 Safari/537.36"
)


async def _url_alive(client: httpx.AsyncClient, url: str) -> bool:
    """True unless the URL is *genuinely gone*. We drop ONLY hard-dead links —
    a confirmed 404/410, a DNS failure, or a refused connection. A 403/429/5xx or
    a timeout means the site is up but blocking our bare probe (bot protection,
    rate limits); the real extractor (Jina / browser UA) can usually still fetch
    it, so keeping it beats losing a good source.

    The old logic ("any non-2xx/3xx → drop") threw away most real sources —
    FIFA.com, news sites, etc. all bot-block a raw HEAD (#4: FIFA kept 1 of 8)."""
    try:
        resp = await client.head(url, follow_redirects=True)
        # Retry GET where servers reject or oddly answer HEAD (incl. a HEAD-only 404).
        if resp.status_code in (403, 404, 405, 429, 501):
            resp = await client.get(url, follow_redirects=True)
        return resp.status_code not in (404, 410)
    except httpx.ConnectError:
        return False   # DNS failure / connection refused → fabricated or dead host
    except Exception:
        return True    # read/connect timeout, protocol quirk → up but slow; keep it


async def _filter_live_sources(sources: list) -> list:
    """Drop candidates whose URLs don't resolve (Claude hallucinates links)."""
    async with httpx.AsyncClient(
        timeout=_URL_CHECK_TIMEOUT,
        headers={"User-Agent": _URL_CHECK_UA},
    ) as client:
        checks = await asyncio.gather(*(_url_alive(client, s.url) for s in sources))
    kept = [s for s, ok in zip(sources, checks) if ok]
    dropped = [s.url for s, ok in zip(sources, checks) if not ok]
    if dropped:
        logger.info("research: dropped %d dead URL(s): %s", len(dropped), dropped)
    return kept


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

    Uses research_topic_with_usage() to collect sources + real token counts
    from the Anthropic response in one pass, then:
      1. Yields a 'searching' heartbeat so the iOS progress screen appears fast.
      2. After Claude returns, yields each source as an SSE 'source' event.
      3. Generates framing_paragraph via build_collection_framing() before persisting.
      4. Persists the Collection record with framing_paragraph.
      5. Writes AiTelemetry with ACTUAL token counts from usage, not estimates.
      6. Yields the terminal 'done' event with collection_id.

    All DB work is done after streaming completes — we never hold a DB
    connection open while waiting on Claude.
    """
    from ai.pipeline import (
        _HAIKU_INPUT_COST,
        _HAIKU_OUTPUT_COST,
        build_collection_framing,
        research_topic_with_usage,
    )

    # Gate: if no API key, yield error event immediately
    if not settings.anthropic_api_key:
        yield _sse({
            "event": "error",
            "message": "ANTHROPIC_API_KEY not configured. Add it to api/.env to enable research.",
        })
        return

    t0 = time.perf_counter()

    # Yield a "searching" heartbeat immediately so the iOS loading screen renders
    # before we spend 10-15s waiting on Claude Sonnet.
    yield _sse({"event": "searching", "topic": topic})

    try:
        result = await research_topic_with_usage(topic)
    except Exception as exc:
        logger.exception("Research stream failed for topic=%r: %s", topic, exc)
        yield _sse({"event": "error", "message": "Research failed. Please try again."})
        return

    sources_collected = result.sources

    if not sources_collected:
        yield _sse({"event": "error", "message": "No sources found. Try a more specific topic."})
        return

    # Verify every candidate URL actually resolves — Claude fabricates
    # plausible-looking deep links (observed 2026-07-15: epa.gov/nps.gov/usgs.gov
    # paths that 404). Prompt tuning cannot fix hallucination; only a fetch can.
    sources_collected = await _filter_live_sources(sources_collected)

    if not sources_collected:
        yield _sse({"event": "error", "message": "No reachable sources found. Try a different topic."})
        return

    # Yield each source
    for idx, source in enumerate(sources_collected):
        yield _sse({
            "event": "source",
            "index": idx,
            "source": {
                "title": source.title,
                "url": source.url,
                "domain": source.domain,
                "rationale": source.rationale,
                "content_type": source.content_type,
            },
        })

    # ── Compute cost from REAL usage ──────────────────────────────────────────
    duration_ms = int((time.perf_counter() - t0) * 1000)
    actual_input = result.input_tokens
    actual_output = result.output_tokens
    actual_cache = result.cache_read_tokens
    # Sonnet pricing: $3.00/1M input, $15.00/1M output; cache reads at 10% input
    actual_cost = (
        Decimal(actual_input) * Decimal("0.000003")
        + Decimal(actual_output) * Decimal("0.000015")
        - Decimal(actual_cache) * Decimal("0.0000027")
    )

    # ── Generate framing_paragraph ────────────────────────────────────────────
    framing: str | None = None
    starter_questions: list[str] = []
    framing_input_tokens = 0
    framing_output_tokens = 0
    if sources_collected and settings.anthropic_api_key:
        try:
            first_summary = sources_collected[0].rationale or sources_collected[0].title
            framing_result = await build_collection_framing(collection_name, first_summary)
            framing = framing_result.sentence
            starter_questions = framing_result.questions
            framing_input_tokens = framing_result.input_tokens
            framing_output_tokens = framing_result.output_tokens
        except Exception:
            logger.warning(
                "framing_paragraph generation failed for collection=%r; proceeding without it",
                collection_name,
            )

    # ── Persist Collection + Telemetry ────────────────────────────────────────
    try:
        collection_id = uuid.uuid4()

        async with AsyncSessionLocal() as db:
            collection = Collection(
                id=collection_id,
                user_id=user_id,
                name=collection_name,
                description=f"AI-curated sources on: {topic}",
                framing_paragraph=framing,
                suggested_questions=starter_questions or None,
                source_count=0,
            )
            db.add(collection)
            # Flush BEFORE adding telemetry: AiTelemetry has a plain FK column
            # (no relationship()) to collections, and SQLAlchemy's unit of work
            # only orders inserts across mappers linked by relationship() — the
            # telemetry INSERT was emitted first and hit the FK constraint,
            # rolling back the whole collection (empirically reproduced 2026-07-11).
            await db.flush()

            db.add(AiTelemetry(
                id=uuid.uuid4(),
                user_id=user_id,
                collection_id=collection_id,
                correlation_id=correlation_id,
                operation="collection_research",
                model="claude-sonnet-4-6",
                input_tokens=actual_input,
                output_tokens=actual_output,
                cache_read_tokens=actual_cache,
                cost_usd=actual_cost,
                duration_ms=duration_ms,
            ))

            if framing is not None:
                framing_cost = (
                    Decimal(framing_input_tokens) * _HAIKU_INPUT_COST
                    + Decimal(framing_output_tokens) * _HAIKU_OUTPUT_COST
                )
                db.add(AiTelemetry(
                    id=uuid.uuid4(),
                    user_id=user_id,
                    collection_id=collection_id,
                    correlation_id=correlation_id,
                    operation="collection_framing",
                    model="claude-haiku-4-5",
                    input_tokens=framing_input_tokens,
                    output_tokens=framing_output_tokens,
                    cache_read_tokens=0,
                    cost_usd=framing_cost,
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


@router.post(
    "/research",
    summary="AI-seeded collection creation via SSE",
    description=(
        "Streams Claude Sonnet source suggestions for a topic. "
        "Returns SSE events: 'searching' heartbeat, 'source' (one per result), "
        "then 'done' with the new collection_id."
    ),
    response_class=StreamingResponse,
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
        data: {"event": "searching", "topic": "..."}
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
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )
