"""Add r2_key column to items (1A-008)

Stores the Cloudflare R2 object key when raw_content is offloaded to R2.
NULL means content is stored in the raw_content TEXT column (Postgres fallback).

Revision ID: 0007
Revises: 0006
Create Date: 2026-06-29
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0007"
down_revision: Union[str, None] = "0006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Nullable VARCHAR — NULL = content in Postgres TEXT; non-NULL = in R2.
    # 500 chars comfortably fits "raw/{uuid}/{uuid}.txt" (72 chars) plus
    # any future key prefix changes.
    op.add_column(
        "items",
        sa.Column("r2_key", sa.String(500), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("items", "r2_key")
