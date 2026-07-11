"""Add collection_id column to ai_telemetry

The AITelemetry model has carried collection_id (added with 1C-001
research telemetry) but the migration was never written — INSERTs
failed with UndefinedColumnError on the live DB, rolling back
collection creation after successful research.

Revision ID: 0008
Revises: 0007
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "ai_telemetry",
        sa.Column(
            "collection_id",
            UUID(as_uuid=True),
            sa.ForeignKey("collections.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index("ix_ai_telemetry_collection_id", "ai_telemetry", ["collection_id"])


def downgrade() -> None:
    op.drop_index("ix_ai_telemetry_collection_id", table_name="ai_telemetry")
    op.drop_column("ai_telemetry", "collection_id")
