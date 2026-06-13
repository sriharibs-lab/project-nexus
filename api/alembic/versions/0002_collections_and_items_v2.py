"""Add collections table; add collection_id FK and insights column to items

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-13

Changes
-------
1. Create `collections` table (id, user_id, name, description,
   framing_paragraph, created_by, timestamps).
2. Add `items.collection_id` NOT NULL FK → collections.id CASCADE.
3. Add `items.insights` TEXT[] first-class column (replaces JSONB lookup).

Zero-data-loss: migration 0001 creates no rows, so the NOT NULL FK is safe.
If applied to a database that already has items rows, a default
collection_id must be supplied or existing rows migrated first.
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
    # 1. collections table
    op.create_table(
        "collections",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("description", sa.Text),
        sa.Column("framing_paragraph", sa.Text),
        sa.Column("created_by", sa.String(10), nullable=False, server_default="user"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_collections_user_id", "collections", ["user_id"])

    # 2. items.collection_id NOT NULL FK
    op.add_column(
        "items",
        sa.Column(
            "collection_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("collections.id", ondelete="CASCADE"),
            nullable=False,
        ),
    )
    op.create_index("ix_items_collection_id", "items", ["collection_id"])

    # 3. items.insights TEXT[] first-class column
    op.add_column(
        "items",
        sa.Column("insights", postgresql.ARRAY(sa.Text)),
    )


def downgrade() -> None:
    op.drop_column("items", "insights")
    op.drop_index("ix_items_collection_id", table_name="items")
    op.drop_column("items", "collection_id")
    op.drop_index("ix_collections_user_id", table_name="collections")
    op.drop_table("collections")
