"""Add error_events (production error telemetry) and artifacts (Create tab)

error_events: one row per captured failure — 5xx/unhandled via middleware, or
an AI call that failed inside a 200 SSE stream via record_error at the call site.
artifacts: generated study artifacts (quiz/paper/…) for a collection.

Revision ID: 0011
Revises: 0010
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "error_events",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("level", sa.String(16), nullable=False, server_default="error"),
        sa.Column("source", sa.String(100), nullable=False),
        sa.Column("status_code", sa.Integer(), nullable=True),
        sa.Column("error_type", sa.String(120), nullable=True),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("path", sa.String(300), nullable=True),
        sa.Column("method", sa.String(10), nullable=True),
        sa.Column("correlation_id", sa.String(64), nullable=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("context", JSONB(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_error_events_level", "error_events", ["level"])
    op.create_index("ix_error_events_source", "error_events", ["source"])
    op.create_index("ix_error_events_correlation_id", "error_events", ["correlation_id"])
    op.create_index("ix_error_events_user_id", "error_events", ["user_id"])
    op.create_index("ix_error_events_created_at", "error_events", ["created_at"])

    op.create_table(
        "artifacts",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("collection_id", UUID(as_uuid=True), sa.ForeignKey("collections.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("kind", sa.String(16), nullable=False),
        sa.Column("title", sa.String(300), nullable=False, server_default=""),
        sa.Column("status", sa.String(16), nullable=False, server_default="ready"),
        sa.Column("content", JSONB(), nullable=True),
        sa.Column("model", sa.String(120), nullable=True),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_artifacts_collection_id", "artifacts", ["collection_id"])
    op.create_index("ix_artifacts_user_id", "artifacts", ["user_id"])
    op.create_index("ix_artifacts_created_at", "artifacts", ["created_at"])


def downgrade() -> None:
    op.drop_table("artifacts")
    op.drop_table("error_events")
