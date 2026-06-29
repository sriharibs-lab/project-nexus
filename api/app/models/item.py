import enum
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import Column, DateTime, Enum, ForeignKey, String, Table, Text, func
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class ContentType(str, enum.Enum):
    article = "article"
    podcast = "podcast"
    video = "video"
    thread = "thread"
    blog = "blog"
    announcement = "announcement"
    youtube = "youtube"
    other = "other"


class IngestStatus(str, enum.Enum):
    pending = "pending"
    processing = "processing"
    completed = "completed"
    failed = "failed"


item_tags = Table(
    "item_tags",
    Base.metadata,
    Column("item_id", UUID(as_uuid=True), ForeignKey("items.id", ondelete="CASCADE"), primary_key=True),
    Column("tag_id", UUID(as_uuid=True), ForeignKey("tags.id", ondelete="CASCADE"), primary_key=True),
)

collection_items = Table(
    "collection_items",
    Base.metadata,
    Column("collection_id", UUID(as_uuid=True), ForeignKey("collections.id", ondelete="CASCADE"), primary_key=True),
    Column("item_id", UUID(as_uuid=True), ForeignKey("items.id", ondelete="CASCADE"), primary_key=True),
    Column("created_at", DateTime(timezone=True), server_default=func.now()),
)


class Item(Base):
    __tablename__ = "items"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    url: Mapped[str] = mapped_column(Text, nullable=False)
    title: Mapped[Optional[str]] = mapped_column(String(500))
    content_type: Mapped[ContentType] = mapped_column(
        Enum(ContentType, name="content_type_enum"), nullable=False, default=ContentType.article
    )
    raw_content: Mapped[Optional[str]] = mapped_column(Text)
    # R2 object key when raw_content is stored in R2 (1A-008).
    # Format: raw/{user_id}/{item_id}.txt
    # None means content lives in raw_content TEXT column (Postgres fallback).
    r2_key: Mapped[Optional[str]] = mapped_column(String(500))
    summary: Mapped[Optional[str]] = mapped_column(Text)
    insights: Mapped[Optional[list]] = mapped_column(ARRAY(Text))
    metadata_: Mapped[Optional[dict]] = mapped_column("metadata", JSONB, default=dict)
    ingest_status: Mapped[IngestStatus] = mapped_column(
        Enum(IngestStatus, name="ingest_status_enum"),
        nullable=False,
        default=IngestStatus.pending,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship("User", back_populates="items")  # noqa: F821
    tags: Mapped[list["Tag"]] = relationship("Tag", secondary="item_tags", back_populates="items")  # noqa: F821
    embedding: Mapped["Embedding | None"] = relationship(  # noqa: F821
        "Embedding", back_populates="item", uselist=False, cascade="all, delete-orphan"
    )
    collections: Mapped[list["Collection"]] = relationship(  # noqa: F821
        "Collection", secondary="collection_items", back_populates="items"
    )
