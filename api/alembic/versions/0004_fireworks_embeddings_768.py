"""Switch embeddings to 768-dim (Fireworks nomic-embed-text-v1.5); add user_interest_profiles

Revision ID: 0004
Revises: 0003
Create Date: 2026-06-19

Changes:
  - user_interest_profiles: created here (was in a duplicate 0002 that was never applied)
  - embeddings.embedding: Vector(1536) → Vector(768) to match nomic-embed-text-v1.5
  - Existing embedding rows deleted (all were stub SHA-256 data, semantically meaningless)
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from pgvector.sqlalchemy import Vector
from sqlalchemy.dialects import postgresql

revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── user_interest_profiles ────────────────────────────────────────────────
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
        sa.Column("topics", postgresql.JSONB, nullable=False, server_default="{}"),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_user_interest_profiles_user_id", "user_interest_profiles", ["user_id"])

    # ── embeddings: 1536-dim → 768-dim ───────────────────────────────────────
    # Delete all rows first — existing vectors are stub SHA-256 data (not semantic).
    # Safe: no real embeddings have been generated yet (OPENAI_API_KEY was not set).
    op.execute("DELETE FROM embeddings")
    op.drop_column("embeddings", "embedding")
    op.add_column("embeddings", sa.Column("embedding", Vector(768), nullable=False))


def downgrade() -> None:
    op.drop_column("embeddings", "embedding")
    op.add_column("embeddings", sa.Column("embedding", Vector(1536), nullable=False))
    op.drop_index("ix_user_interest_profiles_user_id", table_name="user_interest_profiles")
    op.drop_table("user_interest_profiles")
