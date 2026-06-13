import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.users import get_or_create_user
from app.middleware.auth import get_current_user
from app.models.item import ContentType, IngestStatus, Item

router = APIRouter(prefix="/items", tags=["items"])


class TagOut(BaseModel):
    id: str
    name: str
    slug: str


class ItemSummary(BaseModel):
    id: str
    url: str
    title: str | None
    content_type: str
    summary: str | None
    ingest_status: str
    tags: list[TagOut]
    created_at: datetime


class ItemDetail(ItemSummary):
    insights: list[str]
    extractor: str | None
    word_count: int | None


def _to_summary(item: Item) -> ItemSummary:
    return ItemSummary(
        id=str(item.id),
        url=item.url,
        title=item.title,
        content_type=item.content_type.value,
        summary=item.summary,
        ingest_status=item.ingest_status.value,
        tags=[TagOut(id=str(t.id), name=t.name, slug=t.slug) for t in item.tags],
        created_at=item.created_at,
    )


def _to_detail(item: Item) -> ItemDetail:
    meta = item.metadata_ or {}
    return ItemDetail(
        id=str(item.id),
        url=item.url,
        title=item.title,
        content_type=item.content_type.value,
        summary=item.summary,
        ingest_status=item.ingest_status.value,
        tags=[TagOut(id=str(t.id), name=t.name, slug=t.slug) for t in item.tags],
        created_at=item.created_at,
        insights=meta.get("insights", []),
        extractor=meta.get("extractor"),
        word_count=meta.get("word_count"),
    )


@router.get("", response_model=list[ItemSummary])
async def list_items(
    limit: int = 20,
    offset: int = 0,
    status_filter: IngestStatus | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
) -> list[ItemSummary]:
    user = await get_or_create_user(db, current_user["supabase_id"], current_user.get("email"))

    q = (
        select(Item)
        .where(Item.user_id == user.id)
        .options(selectinload(Item.tags))
        .order_by(Item.created_at.desc())
        .limit(min(limit, 100))
        .offset(offset)
    )
    if status_filter:
        q = q.where(Item.ingest_status == status_filter)

    result = await db.execute(q)
    return [_to_summary(item) for item in result.scalars().all()]


@router.get("/{item_id}", response_model=ItemDetail)
async def get_item(
    item_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
) -> ItemDetail:
    user = await get_or_create_user(db, current_user["supabase_id"], current_user.get("email"))

    result = await db.execute(
        select(Item)
        .where(Item.id == item_id, Item.user_id == user.id)
        .options(selectinload(Item.tags))
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    return _to_detail(item)


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(
    item_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_user),
) -> None:
    user = await get_or_create_user(db, current_user["supabase_id"], current_user.get("email"))

    result = await db.execute(
        select(Item).where(Item.id == item_id, Item.user_id == user.id)
    )
    item = result.scalar_one_or_none()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

    await db.delete(item)
    await db.commit()
