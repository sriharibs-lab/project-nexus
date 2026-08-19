import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ErrorEvent(Base):
    """Production error telemetry.

    One row per captured failure — an unhandled 5xx (via middleware) OR an AI
    call that failed *inside* a 200 SSE stream (via record_error at the call
    site). The billing outage on 2026-08-18 was invisible precisely because the
    research endpoint returned HTTP 200 while every Anthropic call 400'd inside
    the stream; the call-site captures close that blind spot.

    Queried by the admin summary endpoint and the GitHub Action alert cron.
    """

    __tablename__ = "error_events"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # "error" (5xx / unhandled / AI failure) | "warning" (handled 4xx worth watching)
    level: Mapped[str] = mapped_column(String(16), nullable=False, default="error", index=True)
    # Logical origin — "http", or an operation name like "collection_research", "chat", "artifact_quiz"
    source: Mapped[str] = mapped_column(String(100), nullable=False, index=True)
    # Provider/status code when known: HTTP status, or an upstream code like Anthropic 400
    status_code: Mapped[int | None] = mapped_column(Integer)
    error_type: Mapped[str | None] = mapped_column(String(120))
    message: Mapped[str] = mapped_column(Text, nullable=False)
    path: Mapped[str | None] = mapped_column(String(300))
    method: Mapped[str | None] = mapped_column(String(10))
    correlation_id: Mapped[str | None] = mapped_column(String(64), index=True)
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    context: Mapped[dict | None] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )
