"""Auth: add user_interest_profiles table

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-18

Changes:
  - Add user_interest_profiles table (SPEC §9a Pillar 4 — Semantic Memory).
    Needed before Phase 1C (Daily Briefing, Connections) planning starts.
    One row per user; topics stored as JSONB for schema-free evolution.
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
    op.create_table(
        "user_interest_profiles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        # topic label → float weight (0.0–1.0); updated by AI pipeline
        sa.Column("topics", postgresql.JSONB, nullable=False, server_default="{}"),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_user_interest_profiles_user_id", "user_interest_profiles", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_user_interest_profiles_user_id", table_name="user_interest_profiles")
    op.drop_table("user_interest_profiles")
