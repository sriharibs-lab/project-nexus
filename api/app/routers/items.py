"""
Collection items router.

source_count floor fix: delete uses GREATEST(source_count - 1, 0) to prevent
negative counts from race conditions or double-deletes. A negative source_count
would display incorrectly on the iOS home screen (Architect note).
"""
import uuid
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.middleware.auth import get_current_user
from app.models.collection import Collection
from app.models.item import ContentType, IngestStatus, Item, collection_items
from app.models.user import User

router = APIRouter(prefix="/collections/{collection_id}/items", tags=["items"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class ItemResponse(BaseModel):
    """
    Lightweight item used in list responses.
    Does NOT include raw_content — avoids large payloads on the list endpoint.
    """
    id: uuid.UUID
    user_id: uuid.UUID
    url: str
    title: Optional[str]
    content_type: ContentType
    summary: Optional[str]
    insights: Optional[List[str]]
    tags: List[str] = []
    ingest_status: IngestStatus
    created_at: datetime
    updated_at: datetime

    @field_validator("tags", mode="before")
    @classmethod
    def _coerce_tags(cls, v: object) -> List[str]:
        if not v:
            return []
        return [t.name if hasattr(t, "name") else str(t) for t in v]

    model_config = {"from_attributes": True}


class ItemDetailResponse(ItemResponse):
    """
    Full item for the Reader view (GET /items/{id}).
    Adds raw_content — the full extracted text — so the iOS Reader can render it.
    raw_content may be None if extraction failed or is still in progress.
    """
    raw_content: Optional[str] = None


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _resolve_user(supabase_id: str, db: AsyncSession) -> User:
    result = await db.execute(select(User).where(User.supabase_id == supabase_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


async def _get_owned_collection(
    collection_id: uuid.UUID, user: User, db: AsyncSession
) -> Collection:
    result = await db.execute(
        select(Collection).where(
            Collection.id == collection_id, Collection.user_id == user.id
        )
    )
    collection = result.scalar_one_or_none()
    if collection is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Collection not found")
    return collection


# ── Routes ────────────────────────────────────────────────────────────────────

@router.get("", response_model=List[ItemResponse])
async def list_items(
    collection_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> List[ItemResponse]:
    user = await _resolve_user(current_user["supabase_id"], db)
    await _get_owned_collection(collection_id, user, db)
    result = await db.execute(
        select(Item)
        .options(selectinload(Item.tags))
        .join(collection_items, collection_items.c.item_id == Item.id)
        .where(collection_items.c.collection_id == collection_id)
        .order_by(collection_items.c.created_at.desc())
    )
    return list(result.scalars().all())


@router.get("/{item_id}", response_model=ItemDetailResponse)
async def get_item(
    collection_id: uuid.UUID,
    item_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ItemDetailResponse:
    user = await _resolve_user(current_user["supabase_id"], db)
    await _get_owned_collection(collection_id, user, db)
    result = await db.execute(
        select(Item)
        .options(selectinload(Item.tags))
        .join(collection_items, collection_items.c.item_id == Item.id)
        .where(
            collection_items.c.collection_id == collection_id,
            Item.id == item_id,
        )
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    # If raw_content was uploaded to R2, fetch it back for the Reader view.
    # Falls back to item.raw_content (Postgres TEXT) if R2 download fails.
    raw_content = item.raw_content
    if item.r2_key and raw_content is None:
        from app.core.storage import download_raw_content
        raw_content = await download_raw_content(item.r2_key)

    return ItemDetailResponse(
        id=item.id,
        user_id=item.user_id,
        url=item.url,
        title=item.title,
        content_type=item.content_type,
        raw_content=raw_content,
        summary=item.summary,
        insights=item.insights,
        tags=[t.name for t in item.tags],
        ingest_status=item.ingest_status,
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(
    collection_id: uuid.UUID,
    item_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    user = await _resolve_user(current_user["supabase_id"], db)
    await _get_owned_collection(collection_id, user, db)

    # Verify item is in this collection
    exists = await db.execute(
        select(collection_items).where(
            collection_items.c.collection_id == collection_id,
            collection_items.c.item_id == item_id,
        )
    )
    if exists.first() is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    # Remove from this collection
    await db.execute(
        delete(collection_items).where(
            collection_items.c.collection_id == collection_id,
            collection_items.c.item_id == item_id,
        )
    )

    # Decrement source_count with floor at 0.
    # GREATEST prevents negative counts from race conditions or double-deletes
    # (Architect note — would show wrong count on iOS home screen).
    await db.execute(
        update(Collection)
        .where(Collection.id == collection_id)
        .values(source_count=func.greatest(Collection.source_count - 1, 0))
    )

    # Delete the item itself only if it no longer belongs to any collection
    remaining = await db.execute(
        select(collection_items).where(collection_items.c.item_id == item_id)
    )
    if remaining.first() is None:
        item_result = await db.execute(select(Item).where(Item.id == item_id))
        item = item_result.scalar_one_or_none()
        if item:
            await db.delete(item)

    await db.commit()
