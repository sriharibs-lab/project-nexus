"""Add feedback, ai_telemetry, performance_logs, audit_logs

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-13
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── feedback ──────────────────────────────────────────────────────────
    op.execute("""
        DO $$ BEGIN
            CREATE TYPE feedback_category_enum AS ENUM ('bug', 'suggestion', 'other');
        EXCEPTION WHEN duplicate_object THEN null; END $$
    """)
    feedback_category = postgresql.ENUM(name="feedback_category_enum", create_type=False)

    op.create_table(
        "feedback",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("text", sa.Text, nullable=False),
        sa.Column("screenshot_url", sa.Text),
        sa.Column("category", feedback_category, nullable=False, server_default="other"),
        sa.Column("app_version", sa.String(50)),
        sa.Column("ios_version", sa.String(50)),
        sa.Column("device_model", sa.String(100)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_feedback_user_id", "feedback", ["user_id"])
    op.create_index("ix_feedback_created_at", "feedback", ["created_at"])

    # ── ai_telemetry ──────────────────────────────────────────────────────
    op.create_table(
        "ai_telemetry",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("item_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("items.id", ondelete="SET NULL"), nullable=True),
        sa.Column("correlation_id", sa.String(64)),
        sa.Column("operation", sa.String(100), nullable=False),  # summarize, embed, chat, etc.
        sa.Column("model", sa.String(100), nullable=False),
        sa.Column("input_tokens", sa.Integer, nullable=False, server_default="0"),
        sa.Column("output_tokens", sa.Integer, nullable=False, server_default="0"),
        sa.Column("cache_read_tokens", sa.Integer, nullable=False, server_default="0"),
        sa.Column("cost_usd", sa.Numeric(10, 6), nullable=False, server_default="0"),
        sa.Column("duration_ms", sa.Integer),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_ai_telemetry_user_id", "ai_telemetry", ["user_id"])
    op.create_index("ix_ai_telemetry_correlation_id", "ai_telemetry", ["correlation_id"])
    op.create_index("ix_ai_telemetry_created_at", "ai_telemetry", ["created_at"])

    # ── performance_logs ──────────────────────────────────────────────────
    op.create_table(
        "performance_logs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("correlation_id", sa.String(64)),
        sa.Column("marker_name", sa.String(100), nullable=False),  # save_to_summary, first_render, etc.
        sa.Column("duration_ms", sa.Integer, nullable=False),
        sa.Column("app_version", sa.String(50)),
        sa.Column("ios_version", sa.String(50)),
        sa.Column("device_model", sa.String(100)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_perf_logs_marker_name", "performance_logs", ["marker_name"])
    op.create_index("ix_perf_logs_created_at", "performance_logs", ["created_at"])

    # ── audit_logs (separate schema, append-only) ─────────────────────────
    op.execute("CREATE SCHEMA IF NOT EXISTS audit")
    op.execute("""
        CREATE TABLE IF NOT EXISTS audit.audit_logs (
            id          BIGSERIAL PRIMARY KEY,
            user_hash   TEXT NOT NULL,
            event_type  TEXT NOT NULL,
            resource_type TEXT,
            resource_id TEXT,
            ip_hash     TEXT,
            user_agent  TEXT,
            metadata    JSONB NOT NULL DEFAULT '{}',
            created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    """)
    op.execute("CREATE INDEX IF NOT EXISTS ix_audit_logs_user_hash ON audit.audit_logs (user_hash)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_audit_logs_event_type ON audit.audit_logs (event_type)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_audit_logs_created_at ON audit.audit_logs (created_at)")
    # Revoke write access from the default app role — audit log is append-only via a dedicated function
    op.execute("REVOKE UPDATE, DELETE ON audit.audit_logs FROM PUBLIC")


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS audit.audit_logs")
    op.execute("DROP SCHEMA IF EXISTS audit")
    op.drop_table("performance_logs")
    op.drop_table("ai_telemetry")
    op.drop_table("feedback")
    op.execute("DROP TYPE IF EXISTS feedback_category_enum")
