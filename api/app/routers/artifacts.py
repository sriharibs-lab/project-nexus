"""
Create-tab artifact studio — generate + list study artifacts for a collection.

POST /v1/collections/{collection_id}/artifacts   {"kind": "quiz" | "paper"}
GET  /v1/collections/{collection_id}/artifacts
DELETE /v1/artifacts/{artifact_id}

Generation runs on an OPEN-SOURCE Fireworks model (settings.fireworks_text_model,
default gpt-oss-120b) grounded in the collection's own sources. Synchronous:
gpt-oss-120b returns a quiz/paper in a few seconds, so the row is created
`ready`. Failures are captured to error_events (source="artifact_<kind>") so a
provider outage shows up in the monitor instead of silently dead cards.
"""

import logging
import uuid
from decimal import Decimal
from typing import Annotated, Literal

from fastapi import APIRouter, Body, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.rag import build_context_block, retrieve_recent_chunks
from app.core.telemetry import record_error
from app.middleware.auth import get_current_user
from app.models.ai_telemetry import AiTelemetry
from app.models.artifact import Artifact
from app.models.collection import Collection
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(tags=["artifacts"])

# gpt-oss-120b on Fireworks — approx serverless pricing (per token).
_FW_TEXT_INPUT_COST = Decimal("0.00000015")   # ~$0.15 / 1M
_FW_TEXT_OUTPUT_COST = Decimal("0.0000006")   # ~$0.60 / 1M

ArtifactKind = Literal["quiz", "paper"]


class ArtifactCreateRequest(BaseModel):
    kind: ArtifactKind


class ArtifactResponse(BaseModel):
    id: uuid.UUID
    collection_id: uuid.UUID
    kind: str
    title: str
    status: str
    content: dict | None
    model: str | None
    created_at: str

    @classmethod
    def of(cls, a: Artifact) -> "ArtifactResponse":
        return cls(
            id=a.id,
            collection_id=a.collection_id,
            kind=a.kind,
            title=a.title,
            status=a.status,
            content=a.content,
            model=a.model,
            created_at=a.created_at.isoformat() if a.created_at else "",
        )


async def _resolve_owned_collection(
    collection_id: uuid.UUID, current_user: dict, db: AsyncSession
) -> tuple[User, Collection]:
    user = (
        await db.execute(select(User).where(User.supabase_id == current_user["supabase_id"]))
    ).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    collection = (
        await db.execute(
            select(Collection).where(Collection.id == collection_id, Collection.user_id == user.id)
        )
    ).scalar_one_or_none()
    if collection is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Collection not found")
    return user, collection


@router.post(
    "/collections/{collection_id}/artifacts",
    response_model=ArtifactResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Generate an artifact (quiz/paper) from a collection's sources",
)
async def create_artifact(
    collection_id: uuid.UUID,
    payload: Annotated[ArtifactCreateRequest, Body()],
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ArtifactResponse:
    from ai.pipeline import generate_paper, generate_quiz

    user, collection = await _resolve_owned_collection(collection_id, current_user, db)

    # Ground generation in the collection's completed sources.
    chunks = await retrieve_recent_chunks(db, collection_id=collection.id, user_id=user.id, top_k=8)
    context = build_context_block(chunks)
    if not context.strip():
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Add and process at least one source before creating artifacts.",
        )

    correlation_id = str(uuid.uuid4())
    try:
        if payload.kind == "quiz":
            result = await generate_quiz(collection.name, context)
        else:
            result = await generate_paper(collection.name, context)
    except Exception as exc:  # provider error, malformed output, empty result
        logger.exception("artifact generation failed kind=%s collection=%s", payload.kind, collection.id)
        await record_error(
            source=f"artifact_{payload.kind}",
            level="error",
            error_type=type(exc).__name__,
            message=str(exc) or type(exc).__name__,
            path=f"/v1/collections/{collection.id}/artifacts",
            method="POST",
            correlation_id=correlation_id,
            user_id=user.id,
            context={"kind": payload.kind, "collection_id": str(collection.id)},
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Couldn't create that just now. Please try again.",
        )

    artifact = Artifact(
        id=uuid.uuid4(),
        collection_id=collection.id,
        user_id=user.id,
        kind=result.kind,
        title=result.title,
        status="ready",
        content=result.content,
        model=result.model,
    )
    db.add(artifact)
    await db.flush()

    cost = (
        Decimal(result.input_tokens) * _FW_TEXT_INPUT_COST
        + Decimal(result.output_tokens) * _FW_TEXT_OUTPUT_COST
    )
    db.add(AiTelemetry(
        id=uuid.uuid4(),
        user_id=user.id,
        collection_id=collection.id,
        correlation_id=correlation_id,
        operation=f"artifact_{result.kind}",
        model=result.model or "fireworks",
        input_tokens=result.input_tokens,
        output_tokens=result.output_tokens,
        cache_read_tokens=0,
        cost_usd=cost,
    ))
    await db.commit()
    await db.refresh(artifact)
    return ArtifactResponse.of(artifact)


@router.get(
    "/collections/{collection_id}/artifacts",
    response_model=list[ArtifactResponse],
    summary="List a collection's artifacts (newest first)",
)
async def list_artifacts(
    collection_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ArtifactResponse]:
    _, collection = await _resolve_owned_collection(collection_id, current_user, db)
    rows = (
        await db.execute(
            select(Artifact)
            .where(Artifact.collection_id == collection.id)
            .order_by(Artifact.created_at.desc())
        )
    ).scalars().all()
    return [ArtifactResponse.of(a) for a in rows]


@router.delete(
    "/artifacts/{artifact_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete an artifact",
)
async def delete_artifact(
    artifact_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    user = (
        await db.execute(select(User).where(User.supabase_id == current_user["supabase_id"]))
    ).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    artifact = (
        await db.execute(
            select(Artifact).where(Artifact.id == artifact_id, Artifact.user_id == user.id)
        )
    ).scalar_one_or_none()
    if artifact is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Artifact not found")
    await db.delete(artifact)
    await db.commit()
