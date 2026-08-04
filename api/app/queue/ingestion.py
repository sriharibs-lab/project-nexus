"""
Durable content ingestion queue backed by pgqueuer (Postgres).

Jobs survive deploys and crashes. Public interface:
  enqueue_item(url, content_type, user_id, collection_id) -> job_id
  init_pgq_pool() -> called once from app lifespan startup
  close_pgq_pool() -> called once from app lifespan shutdown
  start_worker() -> long-running coroutine, called once from app lifespan

pgqueuer uses the same Supabase Postgres as the rest of the app — no
new infrastructure required.
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
import uuid
from decimal import Decimal

import asyncpg
from pgqueuer import PgQueuer
from pgqueuer.db import AsyncpgDriver
from pgqueuer.models import Job
from pgqueuer.queries import Queries
from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.ai_telemetry import AiTelemetry
from app.models.collection import Collection
from app.models.embedding import Embedding
from app.models.item import ContentType, IngestStatus, Item, collection_items, item_tags
from app.models.tag import Tag
from app.models.user_interest_profile import UserInterestProfile

logger = logging.getLogger(__name__)

_pool: asyncpg.Pool | None = None
QUEUE_NAME = "nexus_ingest"


# ---------------------------------------------------------------------------
# Pool lifecycle
# ---------------------------------------------------------------------------

async def init_pgq_pool() -> None:
    global _pool
    dsn = settings.database_url.replace("postgresql+asyncpg://", "postgresql://")
    _pool = await asyncpg.create_pool(dsn, min_size=2, max_size=10)
    logger.info("pgqueuer asyncpg pool created")


async def close_pgq_pool() -> None:
    global _pool
    if _pool is not None:
        await _pool.close()
        _pool = None
        logger.info("pgqueuer asyncpg pool closed")


def get_pgq_pool() -> asyncpg.Pool:
    if _pool is None:
        raise RuntimeError("pgqueuer pool not initialised — call init_pgq_pool() in lifespan")
    return _pool


# ---------------------------------------------------------------------------
# Public enqueue interface
# ---------------------------------------------------------------------------

async def enqueue_item(
    url: str,
    content_type: str,
    user_id: str,
    collection_id: str,
    item_id: str | None = None,
) -> str:
    job_id = str(uuid.uuid4())
    # pgqueuer payloads are bytes — the previous str + type-ignore raised
    # ValueError("a bytes-like object is required") on every enqueue.
    payload = json.dumps({
        "job_id": job_id,
        "url": url,
        "content_type": content_type,
        "user_id": user_id,
        "collection_id": collection_id,
        # Pre-created by the ingest router (status=pending) so the client sees
        # the source instantly; the worker updates this row instead of creating one.
        "item_id": item_id,
    }).encode()
    pool = get_pgq_pool()
    async with pool.acquire() as conn:
        # pgqueuer requires its Driver wrapper — raw asyncpg connections
        # break run()'s LISTEN loop (worker crashed silently at startup).
        driver = AsyncpgDriver(conn)
        await Queries(driver).enqueue(QUEUE_NAME, payload, priority=0)
    logger.info("Enqueued job %s url=%s user=%s collection=%s", job_id, url, user_id, collection_id)
    return job_id


# ---------------------------------------------------------------------------
# Worker
# ---------------------------------------------------------------------------

async def start_worker() -> None:
    """
    Supervised worker: pgqueuer's run() has wedged silently in production —
    "worker started" logged, connection healthy, yet queued jobs sat untouched
    for minutes (observed 2026-07-14: 14 jobs, zero dispatched, no exception).
    The supervisor pairs the worker with a watchdog that checks queue staleness;
    when queued jobs are old and nothing is processing, it kills and restarts
    the worker loop. Restart also re-drains the backlog (initial fetch works
    reliably even when the notify path doesn't).
    """
    while True:
        worker = asyncio.create_task(_run_worker_once(), name="pgq-worker")
        watchdog = asyncio.create_task(_watchdog(worker), name="pgq-watchdog")
        try:
            await worker
            logger.error("pgqueuer run() returned unexpectedly — restarting in 5s")
        except asyncio.CancelledError:
            if worker.cancelled() or worker.done():
                logger.error("pgqueuer worker cancelled by watchdog — restarting in 5s")
            else:
                worker.cancel()
                raise  # app shutdown
        except Exception:
            logger.exception("pgqueuer worker crashed — restarting in 5s")
        finally:
            watchdog.cancel()
        await asyncio.sleep(5)


async def _watchdog(worker: asyncio.Task) -> None:
    """Cancel the worker task if queued jobs are going stale under it."""
    pool = get_pgq_pool()
    while not worker.done():
        await asyncio.sleep(30)
        try:
            async with pool.acquire() as conn:
                stale = await conn.fetchval(
                    """
                    SELECT count(*) FROM pgqueuer
                    WHERE status = 'queued'
                      AND created < now() - interval '45 seconds'
                    """
                )
            if stale and stale > 0:
                logger.error(
                    "WATCHDOG: %d queued job(s) stale >45s with a 'running' worker — force-restarting worker",
                    stale,
                )
                worker.cancel()
                return
        except Exception:
            logger.exception("watchdog check failed (non-fatal)")


async def _run_worker_once() -> None:
    pool = get_pgq_pool()
    async with pool.acquire() as conn:
        # Driver wrapper is REQUIRED — PgQueuer(raw asyncpg conn) crashed
        # run() instantly; create_task swallowed it, so the worker "started"
        # then silently died and jobs sat queued forever (2026-07-11).
        pgq = PgQueuer(AsyncpgDriver(conn))

        @pgq.entrypoint(QUEUE_NAME)
        async def handle_ingest(job: Job) -> None:
            data = json.loads(job.payload)  # payload is bytes; loads accepts it
            logger.info("Processing ingest job url=%s", data.get("url"))
            await _process_job(
                job_id=data["job_id"],
                url=data["url"],
                content_type=data["content_type"],
                user_id=data["user_id"],
                collection_id=data["collection_id"],
                item_id=data.get("item_id"),
            )

        logger.info("pgqueuer ingestion worker started, queue=%s", QUEUE_NAME)
        await pgq.run()


# ---------------------------------------------------------------------------
# Interest profile helpers
# ---------------------------------------------------------------------------

# Weight applied to each new tag on every ingest
_INTEREST_BUMP = 0.1
# Gentle per-tag decay applied to all existing topics that were NOT seen in
# this ingest. Keeps old interests from dominating the profile forever.
_INTEREST_DECAY = 0.02
# Minimum weight below which a topic is pruned from the profile (keeps JSONB small)
_INTEREST_PRUNE_THRESHOLD = 0.05


async def _update_interest_profile(
    db: AsyncSession,
    user_id: uuid.UUID,
    tags: list[str],
) -> None:
    """
    Upsert the UserInterestProfile for `user_id` using `tags` from the just-ingested item.

    Algorithm (MVP, no ML):
      1. Load existing topics dict (or start from {}).
      2. Decay all existing weights by _INTEREST_DECAY (floor 0.0).
      3. Bump each incoming tag by _INTEREST_BUMP (cap 1.0).
      4. Prune topics whose weight fell below _INTEREST_PRUNE_THRESHOLD.
      5. Upsert the row (INSERT … ON CONFLICT DO UPDATE).

    This is intentionally simple: deterministic, testable, no external API call.
    Replace with a model-based approach (e.g. embeddings centroid) when
    Daily Briefing accuracy becomes a product priority.
    """
    # Load existing profile (if any)
    result = await db.execute(
        select(UserInterestProfile).where(UserInterestProfile.user_id == user_id)
    )
    profile = result.scalar_one_or_none()
    existing_topics: dict[str, float] = dict(profile.topics) if profile else {}

    # Decay all existing topic weights
    decayed: dict[str, float] = {
        topic: max(0.0, weight - _INTEREST_DECAY)
        for topic, weight in existing_topics.items()
    }

    # Bump incoming tags
    for tag in tags:
        decayed[tag] = min(1.0, decayed.get(tag, 0.0) + _INTEREST_BUMP)

    # Prune near-zero topics to keep the JSONB compact
    pruned: dict[str, float] = {
        topic: weight
        for topic, weight in decayed.items()
        if weight >= _INTEREST_PRUNE_THRESHOLD
    }

    # Upsert: create profile if missing, or update topics + updated_at in place
    await db.execute(
        pg_insert(UserInterestProfile)
        .values(
            id=uuid.uuid4(),
            user_id=user_id,
            topics=pruned,
        )
        .on_conflict_do_update(
            index_elements=["user_id"],
            set_={"topics": pruned},
        )
    )
    await db.commit()

    logger.debug(
        "Interest profile updated user=%s tags=%s active_topics=%d",
        user_id,
        tags,
        len(pruned),
    )


# ---------------------------------------------------------------------------
# Job processor — full extraction + AI + embedding pipeline
# ---------------------------------------------------------------------------

async def _process_job(
    job_id: str,
    url: str,
    content_type: str,
    user_id: str,
    collection_id: str,
    item_id: str | None = None,
) -> None:
    logger.info("Processing job %s url=%s collection=%s", job_id, url, collection_id)

    async with AsyncSessionLocal() as db:
        t0 = time.perf_counter()

        # The ingest router pre-creates the Item (status=pending) so clients
        # see it immediately; reuse that row. Legacy payloads without item_id
        # (jobs enqueued before 2026-07-14) fall back to creating one here.
        item: Item | None = None
        if item_id is not None:
            item = await db.get(Item, uuid.UUID(item_id))
        if item is None:
            item = Item(
                id=uuid.uuid4(),
                user_id=uuid.UUID(user_id),
                url=url,
                content_type=ContentType(content_type) if content_type in ContentType._value2member_map_ else ContentType.article,
                ingest_status=IngestStatus.processing,
            )
            db.add(item)
        else:
            item.ingest_status = IngestStatus.processing
        await db.flush()

        # Wire into collection immediately (visible as "processing")
        coll_id = uuid.UUID(collection_id)
        await db.execute(
            pg_insert(collection_items)
            .values(collection_id=coll_id, item_id=item.id)
            .on_conflict_do_nothing()
        )
        await db.commit()

        try:
            # ── 1. Extract content ─────────────────────────────────────────
            if "youtube.com" in url or "youtu.be" in url or content_type == "video":
                from pipeline.youtube import extract as _extract
            elif content_type == "podcast":
                from pipeline.deepgram_extractor import extract as _extract  # type: ignore[assignment]
            else:
                from pipeline.jina import extract as _extract  # type: ignore[assignment]

            import asyncio
            import inspect

            # jina.extract is async (1D-005 perf work); youtube/deepgram/
            # readability are sync. to_thread on an async fn returns an
            # un-awaited coroutine → "'coroutine' object has no attribute 'ok'".
            if inspect.iscoroutinefunction(_extract):
                extraction = await _extract(url)
            else:
                extraction = await asyncio.to_thread(_extract, url)

            if not extraction.ok and content_type not in ("video", "podcast"):
                from pipeline.readability import extract as _fallback
                extraction = await asyncio.to_thread(_fallback, url)

            if not extraction.ok:
                raise RuntimeError(f"Extraction failed: {extraction.error}")

            content = extraction.content

            # ── 2. AI summarization ────────────────────────────────────────
            from ai.pipeline import compute_embedding, summarize_item

            ai_t0 = time.perf_counter()
            processed = await summarize_item(content, content_type)
            ai_ms = int((time.perf_counter() - ai_t0) * 1000)

            # Embeddings are NON-FATAL: a provider outage (e.g. Fireworks
            # account suspension, 2026-07-11) must not fail the whole ingest.
            # Item completes without an embedding; semantic search degrades
            # to full-text for this item until backfilled.
            emb_t0 = time.perf_counter()
            emb_result = None
            try:
                emb_result = await compute_embedding(content)
            except Exception as emb_exc:
                logger.warning("Embedding failed (non-fatal) url=%s: %s", url, emb_exc)
            emb_ms = int((time.perf_counter() - emb_t0) * 1000)

            # ── 3. Update item ─────────────────────────────────────────────
            if extraction.title:
                item.title = extraction.title

            # Upload raw_content to R2. Falls back to Postgres TEXT on failure.
            from app.core.storage import upload_raw_content
            r2_key = await upload_raw_content(
                user_id=str(item.user_id),
                item_id=str(item.id),
                content=content,
            )
            if r2_key:
                # Content is in R2 — clear raw_content to avoid double-storage
                item.r2_key = r2_key
                item.raw_content = None
            else:
                # R2 unavailable — store in Postgres TEXT (TestFlight fallback)
                item.raw_content = content

            item.summary = processed.tldr
            item.insights = processed.insights
            item.metadata_ = {
                "extractor": extraction.extractor,
                "word_count": extraction.word_count,
                "extraction_ms": int(extraction.elapsed_ms),
                **extraction.metadata,
            }
            item.ingest_status = IngestStatus.completed

            # Increment source_count only on success — prevents phantom counts
            await db.execute(
                update(Collection)
                .where(Collection.id == coll_id)
                .values(source_count=Collection.source_count + 1)
            )

            # ── 4. Embedding (skipped when the provider failed above) ──────
            if emb_result is not None:
                db.add(Embedding(
                    id=uuid.uuid4(),
                    item_id=item.id,
                    embedding=emb_result.vector,
                    model=emb_result.model,
                    dimensions=emb_result.dimensions,
                ))

            # ── 5. Tags ────────────────────────────────────────────────────
            for tag_name in processed.tags:
                slug = tag_name.lower().replace(" ", "-")[:100]
                tag_res = await db.execute(
                    select(Tag).where(Tag.user_id == item.user_id, Tag.slug == slug)
                )
                tag = tag_res.scalar_one_or_none()
                if not tag:
                    tag = Tag(id=uuid.uuid4(), user_id=item.user_id, name=tag_name, slug=slug)
                    db.add(tag)
                    await db.flush()
                await db.execute(
                    pg_insert(item_tags)
                    .values(item_id=item.id, tag_id=tag.id)
                    .on_conflict_do_nothing()
                )

            # ── 6. Telemetry ───────────────────────────────────────────────
            db.add(AiTelemetry(
                id=uuid.uuid4(),
                user_id=item.user_id,
                item_id=item.id,
                correlation_id=job_id,
                operation="summarize",
                model=processed.model,
                input_tokens=processed.input_tokens,
                output_tokens=processed.output_tokens,
                cache_read_tokens=processed.cache_read_tokens,
                cost_usd=processed.cost_usd + (emb_result.cost_usd if emb_result else 0),
                duration_ms=ai_ms + emb_ms,
            ))

            await db.commit()

            # ── 7. Interest profile update ─────────────────────────────────
            # Update topic weights for Daily Briefing (1C-010) and Connections.
            # Non-fatal: a failure here must never roll back the ingest job.
            try:
                await _update_interest_profile(db, user_id=item.user_id, tags=processed.tags)
            except Exception as profile_exc:
                logger.warning(
                    "Interest profile update failed for user %s: %s", item.user_id, profile_exc
                )

            # ── 8. Framing paragraph (first completed source only) ─────────
            try:
                from sqlalchemy import func as sqlfunc
                count_result = await db.execute(
                    select(sqlfunc.count()).select_from(Item)
                    .join(collection_items, collection_items.c.item_id == Item.id)
                    .where(
                        collection_items.c.collection_id == coll_id,
                        Item.ingest_status == IngestStatus.completed,
                    )
                )
                if count_result.scalar() == 1 and item.summary:
                    col_res = await db.execute(select(Collection).where(Collection.id == coll_id))
                    col = col_res.scalar_one_or_none()
                    if col and not col.framing_paragraph:
                        from ai.pipeline import (
                            _HAIKU_INPUT_COST,
                            _HAIKU_OUTPUT_COST,
                            build_collection_framing,
                        )
                        framing_result = await build_collection_framing(col.name, item.summary)
                        col.framing_paragraph = framing_result.sentence
                        col.suggested_questions = framing_result.questions or None
                        framing_cost = (
                            Decimal(framing_result.input_tokens) * _HAIKU_INPUT_COST
                            + Decimal(framing_result.output_tokens) * _HAIKU_OUTPUT_COST
                        )
                        db.add(AiTelemetry(
                            id=uuid.uuid4(),
                            user_id=item.user_id,
                            collection_id=coll_id,
                            correlation_id=job_id,
                            operation="collection_framing",
                            model="claude-haiku-4-5",
                            input_tokens=framing_result.input_tokens,
                            output_tokens=framing_result.output_tokens,
                            cache_read_tokens=0,
                            cost_usd=framing_cost,
                        ))
                        await db.commit()
            except Exception as framing_exc:
                logger.warning("Framing generation failed for collection %s: %s", coll_id, framing_exc)

            total_ms = int((time.perf_counter() - t0) * 1000)
            logger.info("Job completed item_id=%s total_ms=%d", item.id, total_ms)

        except Exception as exc:
            logger.exception("Job failed %s: %s", job_id, exc)
            item.ingest_status = IngestStatus.failed
            item.metadata_ = {**(item.metadata_ or {}), "error": str(exc)}
            await db.commit()
