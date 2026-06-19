"""
Collections CRUD router.

Note on source_count: maintained as a denormalized integer. Incremented by
the ingest pipeline on completion, decremented on item removal. Uses
GREATEST(source_count - 1, 0) to prevent negative counts from race conditions
or double-deletes (Architect note — would display incorrectly on iOS home screen).
"""
import uuid
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.middleware.auth import get_current_user
from app.models.collection import Collection, CollectionCreatedBy
from app.models.user import User

router = APIRouter(prefix="/collections", tags=["collections"])


# ── Schemas ──────────────────────────────────────────────────────────────────

class CollectionCreate(BaseModel):
    name: str
    description: Optional[str] = None
    framing_paragraph: Optional[str] = None
    created_by: CollectionCreatedBy = CollectionCreatedBy.user


class CollectionUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    framing_paragraph: Optional[str] = None


class CollectionResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    name: str
    description: Optional[str]
    framing_paragraph: Optional[str]
    created_by: CollectionCreatedBy
    source_count: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


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

@router.get("", response_model=List[CollectionResponse])
async def list_collections(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> List[CollectionResponse]:
    user = await _resolve_user(current_user["supabase_id"], db)
    result = await db.execute(
        select(Collection)
        .where(Collection.user_id == user.id)
        .order_by(Collection.created_at.desc())
    )
    return list(result.scalars().all())


@router.post("", status_code=status.HTTP_201_CREATED, response_model=CollectionResponse)
async def create_collection(
    payload: CollectionCreate,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CollectionResponse:
    user = await _resolve_user(current_user["supabase_id"], db)
    collection = Collection(
        user_id=user.id,
        name=payload.name,
        description=payload.description,
        framing_paragraph=payload.framing_paragraph,
        created_by=payload.created_by,
    )
    db.add(collection)
    await db.commit()
    await db.refresh(collection)
    return collection


@router.get("/{collection_id}", response_model=CollectionResponse)
async def get_collection(
    collection_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CollectionResponse:
    user = await _resolve_user(current_user["supabase_id"], db)
    return await _get_owned_collection(collection_id, user, db)


@router.patch("/{collection_id}", response_model=CollectionResponse)
async def update_collection(
    collection_id: uuid.UUID,
    payload: CollectionUpdate,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CollectionResponse:
    user = await _resolve_user(current_user["supabase_id"], db)
    collection = await _get_owned_collection(collection_id, user, db)
    if payload.name is not None:
        collection.name = payload.name
    if payload.description is not None:
        collection.description = payload.description
    if payload.framing_paragraph is not None:
        collection.framing_paragraph = payload.framing_paragraph
    await db.commit()
    await db.refresh(collection)
    return collection


@router.delete("/{collection_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_collection(
    collection_id: uuid.UUID,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    user = await _resolve_user(current_user["supabase_id"], db)
    collection = await _get_owned_collection(collection_id, user, db)
    await db.delete(collection)
    await db.commit()
