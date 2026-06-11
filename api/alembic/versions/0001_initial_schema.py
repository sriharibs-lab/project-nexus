"""Initial schema: users, items, tags, item_tags, embeddings

Revision ID: 0001
Revises:
Create Date: 2026-06-05
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from pgvector.sqlalchemy import Vector
from sqlalchemy.dialects import postgresql

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

EMBEDDING_DIM = 1536


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS vector")

    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("supabase_id", sa.String(255), nullable=False, unique=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_users_supabase_id", "users", ["supabase_id"])

    content_type_enum = postgresql.ENUM(
        "article", "podcast", "video", "thread", "blog", "announcement", "other",
        name="content_type_enum",
    )
    ingest_status_enum = postgresql.ENUM(
        "pending", "processing", "completed", "failed",
        name="ingest_status_enum",
    )
    content_type_enum.create(op.get_bind())
    ingest_status_enum.create(op.get_bind())

    op.create_table(
        "items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("url", sa.Text, nullable=False),
        sa.Column("title", sa.String(500)),
        sa.Column("content_type", sa.Enum("article", "podcast", "video", "thread", "blog", "announcement", "other", name="content_type_enum", create_type=False), nullable=False, server_default="article"),
        sa.Column("raw_content", sa.Text),
        sa.Column("summary", sa.Text),
        sa.Column("metadata", postgresql.JSONB, server_default="{}"),
        sa.Column("ingest_status", sa.Enum("pending", "processing", "completed", "failed", name="ingest_status_enum", create_type=False), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_items_user_id", "items", ["user_id"])
    op.create_index("ix_items_ingest_status", "items", ["ingest_status"])

    op.create_table(
        "tags",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("slug", sa.String(100), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_tags_user_id", "tags", ["user_id"])
    op.create_index("ix_tags_slug", "tags", ["slug"])

    op.create_table(
        "item_tags",
        sa.Column("item_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("items.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("tag_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tags.id", ondelete="CASCADE"), primary_key=True),
    )

    op.create_table(
        "embeddings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("item_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("items.id", ondelete="CASCADE"), nullable=False, unique=True),
        sa.Column("embedding", Vector(EMBEDDING_DIM), nullable=False),
        sa.Column("model", sa.String(100), nullable=False, server_default="text-embedding-3-small"),
        sa.Column("dimensions", sa.Integer, nullable=False, server_default=str(EMBEDDING_DIM)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_embeddings_item_id", "embeddings", ["item_id"])
    # HNSW index for fast ANN similarity search
    op.execute(
        "CREATE INDEX ix_embeddings_hnsw ON embeddings USING hnsw (embedding vector_cosine_ops)"
    )


def downgrade() -> None:
    op.drop_table("embeddings")
    op.drop_table("item_tags")
    op.drop_table("tags")
    op.drop_table("items")
    op.drop_table("users")
    op.execute("DROP TYPE IF EXISTS content_type_enum")
    op.execute("DROP TYPE IF EXISTS ingest_status_enum")
    op.execute("DROP EXTENSION IF EXISTS vector")
