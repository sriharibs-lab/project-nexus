"""
User interest profile — SPEC §9a Pillar 4 (Semantic Memory).

Stores per-user topic interest vectors used by Daily Briefing and
Connections features (Phase 1C).  Persisted as JSONB so it can grow
without schema migrations as the AI layer matures.

Schema:
  user_id     FK → users.id (one-to-one)
  topics      JSONB  e.g. {"machine learning": 0.9, "startup": 0.7}
              Keys are topic labels; values are 0.0–1.0 interest weights.
  updated_at  timestamp — refreshed each time the AI updates the profile
"""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class UserInterestProfile(Base):
    __tablename__ = "user_interest_profiles"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    # topic name → interest weight (0.0–1.0); managed by AI pipeline
    topics: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    user: Mapped["User"] = relationship("User", back_populates="interest_profile")  # noqa: F821
