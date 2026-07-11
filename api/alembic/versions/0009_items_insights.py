"""Add insights column to items

Last of the model↔DB drift from the era when models/__init__.py didn't
import every model (alembic autogenerate was blind to them). A full
metadata-vs-live-DB diff on 2026-07-11 shows this is the only remaining
gap; schema is in sync after this migration.

Revision ID: 0009
Revises: 0008
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import ARRAY

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("items", sa.Column("insights", ARRAY(sa.Text()), nullable=True))


def downgrade() -> None:
    op.drop_column("items", "insights")
