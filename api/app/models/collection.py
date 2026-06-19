"""
Collection model.

source_count is a denormalized integer maintained by the application layer.
Avoids COUNT(items) subqueries on every home-screen list load.
Updated by the ingest router on item add/remove; never derived at query time.
"""
import enum
import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class CollectionCreatedBy(str, enum.Enum):
    user = "user"
    ai = "ai"


class Collection(Base):
    __tablename__ = "collections"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text)
    framing_paragraph: Mapped[Optional[str]] = mapped_column(Text)
    created_by: Mapped[CollectionCreatedBy] = mapped_column(
        String(10), nullable=False, default=CollectionCreatedBy.user
    )
    # Denormalized count — maintained by app layer on item add/remove.
    source_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship("User", back_populates="collections")  # noqa: F821
    items: Mapped[list["Item"]] = relationship(  # noqa: F821
        "Item", secondary="collection_items", back_populates="collections"
    )
