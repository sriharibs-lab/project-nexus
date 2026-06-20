"""Add daily_briefings table (1C-010)

Revision ID: 0006
Revises: 0005
Create Date: 2026-06-20
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0006"
down_revision: Union[str, None] = "0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # daily_briefings
    # ------------------------------------------------------------------
    op.create_table(
        "daily_briefings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("headline", sa.Text, nullable=False),
        sa.Column("sections", postgresql.JSONB, nullable=False, server_default="[]"),
        sa.Column("input_tokens", sa.Integer, nullable=False, server_default="0"),
        sa.Column("output_tokens", sa.Integer, nullable=False, server_default="0"),
        sa.Column("items_used", sa.Integer, nullable=False, server_default="0"),
        sa.Column(
            "created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False
        ),
    )
    op.create_index("ix_daily_briefings_user_id", "daily_briefings", ["user_id"])
    op.create_index("ix_daily_briefings_created_at", "daily_briefings", ["created_at"])


def downgrade() -> None:
    op.drop_table("daily_briefings")
