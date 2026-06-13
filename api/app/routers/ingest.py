import uuid

from fastapi import APIRouter, Depends, status
from pydantic import BaseModel, HttpUrl
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.users import get_or_create_user
from app.middleware.auth import get_current_user
from app.models.item import ContentType, IngestStatus, Item
from app.queue.ingestion import enqueue_item

router = APIRouter(prefix="/ingest", tags=["ingest"])


class IngestRequest(BaseModel):
    url: HttpUrl
    content_type: ContentType = ContentType.article


class IngestResponse(BaseModel):
    item_id: str
    status: str
    message: str


@router.post("", status_code=status.HTTP_202_ACCEPTED, response_model=IngestResponse)
async def ingest_item(
    payload: IngestRequest,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
) -> IngestResponse:
    user = await get_or_create_user(
        db,
        supabase_id=current_user["supabase_id"],
        email=current_user.get("email"),
    )

    item = Item(
        id=uuid.uuid4(),
        user_id=user.id,
        url=str(payload.url),
        content_type=payload.content_type,
        ingest_status=IngestStatus.pending,
    )
    db.add(item)
    await db.commit()

    await enqueue_item(
        item_id=item.id,
        url=str(payload.url),
        content_type=payload.content_type.value,
        user_id=user.id,
    )

    return IngestResponse(
        item_id=str(item.id),
        status="queued",
        message="Item queued for ingestion",
    )
