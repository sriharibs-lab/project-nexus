"""Add collections table and collection_id FK on items

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-13

Changes:
- collections table with source_count (denormalized integer, maintained by app layer)
- items.collection_id FK → collections.id (SET NULL on collection delete)

source_count rationale: home screen must display item counts per collection.
A COUNT(*) subquery on every list load is cheap at 10 users but expensive at
10K concurrent users with large collections. Denormalizing now costs one
migration and zero risk. Waiting means a model + API breaking change under
real data.
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
        "collections",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("description", sa.Text),
        # Denormalized — never derive with COUNT(*) at query time.
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

    # Every item belongs to one collection. SET NULL on collection delete so
    # items are not silently destroyed if a collection is removed.
    op.add_column(
        "items",
        sa.Column(
            "collection_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("collections.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_items_collection_id", "items", ["collection_id"])


def downgrade() -> None:
    op.drop_index("ix_items_collection_id", table_name="items")
    op.drop_column("items", "collection_id")
    op.drop_index("ix_collections_user_id", table_name="collections")
    op.drop_table("collections")
