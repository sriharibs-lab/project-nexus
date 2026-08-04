"""
Collection model — the root organizational unit in Nexus.

Every Item belongs to one or more Collections via the collection_items join table
(defined in item.py — single source of truth for that association table).
The AI Nexus tab and chat endpoint are always scoped to a single Collection.
"""

import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class CollectionCreatedBy(str, enum.Enum):
    """
    How the collection was created.

    - user: created manually by the user (via "Start with a link" or blank collection)
    - ai:   seeded by the AI research flow (via "Research a topic")

    The DB column is VARCHAR(10) DEFAULT 'user' (migration 0003). Using str+enum
    so Pydantic and SQLAlchemy both accept the string values without a DB enum type.
    """

    user = "user"
    ai = "ai"


class Collection(Base):
    __tablename__ = "collections"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    framing_paragraph: Mapped[str | None] = mapped_column(Text)
    # 3 AI-generated, collection-specific starter questions (Ask-tab chips).
    suggested_questions: Mapped[list[str] | None] = mapped_column(ARRAY(Text))
    created_by: Mapped[CollectionCreatedBy] = mapped_column(
        # native_enum=False: the DB column is VARCHAR(10), not a Postgres enum
        # type — without it asyncpg casts $n::collectioncreatedby and fails
        # with UndefinedObjectError on INSERT (found 2026-07-11).
        Enum(
            CollectionCreatedBy,
            values_callable=lambda e: [m.value for m in e],
            create_type=False,
            native_enum=False,
        ),
        nullable=False,
        default=CollectionCreatedBy.user,
        server_default=CollectionCreatedBy.user.value,
    )
    source_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship("User", back_populates="collections")  # noqa: F821
    items: Mapped[list["Item"]] = relationship(  # noqa: F821
        "Item",
        secondary="collection_items",
        back_populates="collections",
    )
