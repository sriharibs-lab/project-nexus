import enum
import uuid
from datetime import datetime
from typing import List, Optional

from sqlalchemy import ARRAY, Column, DateTime, Enum, ForeignKey, String, Table, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class ContentType(str, enum.Enum):
    """Canonical ContentType enum — single source of truth.

    Previously duplicated in api/pipeline/base.py (ARTICLE/VIDEO/PODCAST only).
    api/pipeline/base.py now imports from here to avoid silent routing mismatches.
    Covers all content types the ingest router accepts and the AI pipeline routes on.
    """

    article = "article"
    podcast = "podcast"
    video = "video"
    thread = "thread"
    blog = "blog"
    announcement = "announcement"
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


class Item(Base):
    __tablename__ = "items"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    collection_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("collections.id", ondelete="CASCADE"), nullable=False, index=True
    )
    url: Mapped[str] = mapped_column(Text, nullable=False)
    title: Mapped[Optional[str]] = mapped_column(String(500))
    content_type: Mapped[ContentType] = mapped_column(
        Enum(ContentType, name="content_type_enum"), nullable=False, default=ContentType.article
    )
    raw_content: Mapped[Optional[str]] = mapped_column(Text)
    summary: Mapped[Optional[str]] = mapped_column(Text)
    insights: Mapped[Optional[List[str]]] = mapped_column(ARRAY(Text))
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
    collection: Mapped["Collection"] = relationship("Collection", back_populates="items")  # noqa: F821
    tags: Mapped[List["Tag"]] = relationship("Tag", secondary="item_tags", back_populates="items")  # noqa: F821
    embedding: Mapped[Optional["Embedding"]] = relationship(  # noqa: F821
        "Embedding", back_populates="item", uselist=False, cascade="all, delete-orphan"
    )
