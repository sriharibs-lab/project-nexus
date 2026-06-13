import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, HttpUrl
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.middleware.auth import get_current_user
from app.models.collection import Collection
from app.models.item import ContentType
from app.models.user import User
from app.queue.ingestion import enqueue_item

router = APIRouter(prefix="/ingest", tags=["ingest"])


class IngestRequest(BaseModel):
    url: HttpUrl
    collection_id: uuid.UUID
    # Validated against the canonical ContentType enum — prevents silent
    # routing errors when an unknown content_type bypasses AI path selection.
    content_type: ContentType = ContentType.article


class IngestResponse(BaseModel):
    job_id: str
    status: str
    message: str


@router.post("", status_code=status.HTTP_202_ACCEPTED, response_model=IngestResponse)
async def ingest_item(
    payload: IngestRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> IngestResponse:
    # Resolve user row
    result = await db.execute(select(User).where(User.supabase_id == current_user["supabase_id"]))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    # Validate collection ownership
    col_result = await db.execute(
        select(Collection).where(
            Collection.id == payload.collection_id, Collection.user_id == user.id
        )
    )
    if col_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Collection not found")

    job_id = await enqueue_item(
        url=str(payload.url),
        content_type=payload.content_type.value,
        user_id=str(user.id),
        collection_id=str(payload.collection_id),
    )
    return IngestResponse(
        job_id=job_id,
        status="queued",
        message="Item queued for ingestion",
    )
