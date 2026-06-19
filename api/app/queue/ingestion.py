"""
Durable content ingestion queue backed by pgqueuer (Postgres).

Jobs survive deploys and crashes. Public interface is unchanged:
  enqueue_item(url, content_type, user_id) -> job_id
  init_pgq_pool() -> called once from app lifespan
  close_pgq_pool() -> called once on shutdown
  start_worker() -> long-running coroutine, called once from app lifespan

pgqueuer uses the same Supabase Postgres as the rest of the app — no
new infrastructure required.
"""

from __future__ import annotations

import json
import logging
import uuid

import asyncpg
from pgqueuer import PgQueuer
from pgqueuer.models import Job

from app.core.config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Module-level asyncpg pool — initialised once in lifespan
# ---------------------------------------------------------------------------

_pool: asyncpg.Pool | None = None

QUEUE_NAME = "nexus_ingest"


async def init_pgq_pool() -> None:
    """Create the asyncpg connection pool. Call once in app lifespan startup."""
    global _pool
    # pgqueuer requires asyncpg (not SQLAlchemy) — use the same DATABASE_URL
    # but strip the +asyncpg driver prefix if present (asyncpg expects plain DSN)
    dsn = settings.database_url.replace("postgresql+asyncpg://", "postgresql://")
    _pool = await asyncpg.create_pool(dsn, min_size=2, max_size=10)
    logger.info("pgqueuer asyncpg pool created")


async def close_pgq_pool() -> None:
    """Drain and close the asyncpg pool. Call once in app lifespan shutdown."""
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None
        logger.info("pgqueuer asyncpg pool closed")


def get_pgq_pool() -> asyncpg.Pool:
    """Return the module-level pool. Raises if init_pgq_pool() was not called."""
    if _pool is None:
        raise RuntimeError(
            "pgqueuer pool is not initialised — call init_pgq_pool() in app lifespan startup"
        )
    return _pool


# ---------------------------------------------------------------------------
# Public enqueue interface (unchanged signature)
# ---------------------------------------------------------------------------


async def enqueue_item(url: str, content_type: str, user_id: str) -> str:
    """
    Persist a new ingest job to Postgres via pgqueuer and return its job_id.

    The returned job_id is a client-generated UUID stored in the job payload so
    callers can reference it before the row is inserted by pgqueuer internals.
    """
    job_id = str(uuid.uuid4())
    payload = json.dumps({"job_id": job_id, "url": url, "content_type": content_type, "user_id": user_id})

    pool = get_pgq_pool()
    async with pool.acquire() as conn:
        pgq = PgQueuer(conn)
        await pgq.queries.enqueue(
            QUEUE_NAME,
            payload,  # type: ignore[arg-type]
            priority=0,
        )

    logger.info("Enqueued job %s for url=%s user=%s", job_id, url, user_id)
    return job_id


# ---------------------------------------------------------------------------
# Worker
# ---------------------------------------------------------------------------


async def start_worker() -> None:
    """
    Long-running coroutine — call once from app lifespan.

    pgqueuer polls Postgres with LISTEN/NOTIFY so idle CPU is near zero.
    Failed jobs use on_failure='log' — they stay in the DB with status='exception'
    for inspection, and are not silently discarded.
    """
    pool = get_pgq_pool()
    async with pool.acquire() as conn:
        pgq = PgQueuer(conn)

        @pgq.entrypoint(QUEUE_NAME)
        async def handle_ingest(job: Job) -> None:
            data = json.loads(job.payload)  # type: ignore[arg-type]
            await _process_job(
                job_id=data["job_id"],
                url=data["url"],
                content_type=data["content_type"],
                user_id=data["user_id"],
            )

        logger.info("pgqueuer ingestion worker started, listening on queue=%s", QUEUE_NAME)
        await pgq.run()


# ---------------------------------------------------------------------------
# Job processor (stub — will be replaced with pipeline wiring in 1C-005)
# ---------------------------------------------------------------------------


async def _process_job(job_id: str, url: str, content_type: str, user_id: str) -> None:
    """
    Stub processor — replace with real fetch → parse → embed → store pipeline.

    Raising an exception here marks the job 'exception' in pgqueuer's DB table,
    making it visible for inspection rather than silently discarded.
    """
    logger.info(
        "Processing job %s url=%s content_type=%s user=%s",
        job_id, url, content_type, user_id,
    )
    # TODO (1C-005): fetch content, extract text, generate embedding, persist Item + Embedding
    # TODO (1C-010): update UserInterestProfile topic weights post-ingest
