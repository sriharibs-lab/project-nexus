"""Collections table + collection_items join table (many-to-many)

Revision ID: 0003
Revises: 0002
Create Date: 2026-06-13

Changes:
- collections table (id, user_id, name, description, framing_paragraph,
  created_by, source_count, timestamps)
- collection_items join table (collection_id, item_id, created_at)
  — allows one item to appear in multiple collections
- No items.collection_id column: membership is entirely through collection_items
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
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
        sa.Column("source_count", sa.Integer, nullable=False, server_default="0"),
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

    op.create_table(
        "collection_items",
        sa.Column(
            "collection_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("collections.id", ondelete="CASCADE"),
            primary_key=True,
            nullable=False,
        ),
        sa.Column(
            "item_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("items.id", ondelete="CASCADE"),
            primary_key=True,
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_collection_items_item_id", "collection_items", ["item_id"])


def downgrade() -> None:
    op.drop_index("ix_collection_items_item_id", table_name="collection_items")
    op.drop_table("collection_items")
    op.drop_index("ix_collections_user_id", table_name="collections")
    op.drop_table("collections")
