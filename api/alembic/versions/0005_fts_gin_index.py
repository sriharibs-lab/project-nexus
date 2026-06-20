"""Add GIN FTS index on items(title, summary) for full-text search (1C-006)

Revision ID: 0005
Revises: 0004
Create Date: 2026-06-20

Changes:
  GIN tsvector index on items(title, summary) for fast full-text search.
  The expression matches exactly what search.py uses in its FTS leg:
    to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(summary, ''))
  'english' dictionary handles stemming/stop-words for English content.

Note: Embedding dimension change (1536→768) is already covered by 0004.
"""

from typing import Sequence, Union

from alembic import op

revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # GIN FTS index on items — same expression used in search.py _FTS_QUERY.
    # CONCURRENTLY avoids table lock; IF NOT EXISTS makes it safe to re-run.
    op.execute("""
        CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_items_fts
        ON items
        USING gin(to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(summary, '')))
    """)


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_items_fts")
