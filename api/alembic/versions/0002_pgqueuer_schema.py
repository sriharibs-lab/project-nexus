"""pgqueuer schema: durable job queue tables

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-19

Creates the two tables that pgqueuer requires:
  - pgqueuer_statistics — job throughput counters
  - pgqueuer_jobs       — durable job rows (status, payload, priority)

IF NOT EXISTS guards make this migration safe to re-run and compatible with
pgqueuer's own create_schema() helper if it was called out-of-band.

pgqueuer also installs a LISTEN/NOTIFY trigger on pgqueuer_jobs so the
worker wakes up immediately when a job is enqueued rather than polling.
"""

from typing import Sequence, Union

from alembic import op

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # pgqueuer statistics table — tracks completed/failed counts per queue
    op.execute("""
        CREATE TABLE IF NOT EXISTS pgqueuer_statistics (
            id          SERIAL PRIMARY KEY,
            created     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
            count       INTEGER NOT NULL DEFAULT 0,
            priority    INTEGER NOT NULL DEFAULT 0,
            queue_name  TEXT NOT NULL,
            status      TEXT NOT NULL,
            time_in_queue INTERVAL
        )
    """)

    # Main job table
    op.execute("""
        CREATE TABLE IF NOT EXISTS pgqueuer_jobs (
            id          BIGSERIAL PRIMARY KEY,
            priority    INTEGER NOT NULL DEFAULT 0,
            created     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
            updated     TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
            queue_name  TEXT NOT NULL,
            status      TEXT NOT NULL DEFAULT 'queued',
            payload     JSONB,
            CONSTRAINT pgqueuer_jobs_status_check
                CHECK (status IN ('queued', 'picked', 'successful', 'exception'))
        )
    """)

    # Index for efficient FIFO dequeue by queue_name + priority
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_pgqueuer_jobs_queue_status_priority
        ON pgqueuer_jobs (queue_name, priority DESC, id ASC)
        WHERE status = 'queued'
    """)

    # LISTEN/NOTIFY function — wakes up idle workers without polling
    op.execute("""
        CREATE OR REPLACE FUNCTION pgqueuer_jobs_notify()
        RETURNS TRIGGER LANGUAGE plpgsql AS $$
        BEGIN
            PERFORM pg_notify('pgqueuer', NEW.queue_name);
            RETURN NEW;
        END;
        $$
    """)

    op.execute("""
        CREATE OR REPLACE TRIGGER pgqueuer_jobs_notify_trigger
        AFTER INSERT ON pgqueuer_jobs
        FOR EACH ROW EXECUTE FUNCTION pgqueuer_jobs_notify()
    """)


def downgrade() -> None:
    op.execute("DROP TRIGGER IF EXISTS pgqueuer_jobs_notify_trigger ON pgqueuer_jobs")
    op.execute("DROP FUNCTION IF EXISTS pgqueuer_jobs_notify")
    op.execute("DROP INDEX IF EXISTS ix_pgqueuer_jobs_queue_status_priority")
    op.execute("DROP TABLE IF EXISTS pgqueuer_jobs")
    op.execute("DROP TABLE IF EXISTS pgqueuer_statistics")
