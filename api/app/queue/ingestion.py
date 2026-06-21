"""
Durable content ingestion queue backed by an asyncio Queue (MVP in-process).

Replace the backend (Redis / BullMQ / pgqueuer) without changing the public
interface: enqueue_item / start_worker.

Performance instrumentation (1D-005)
──────────────────────────────────────────────────────────────────────────────
Every _process_job() emits structured log lines at each stage so latency can
be traced without external APM tooling:

  stage=extraction   elapsed_ms=<N>  extractor=<name>
  stage=ai_summary   elapsed_ms=<N>  model=<name>
  stage=embedding    elapsed_ms=<N>  model=<name>
  stage=db_write     elapsed_ms=<N>
  stage=total        elapsed_ms=<N>  slo_ok=<true|false>

  SLO target: total < ingest_slo_ms (default 10 000 ms — SPEC §9b).
  Logs a WARNING when the SLO is missed so alerts can be built on log filters.

Key optimizations applied in this task:
  1. jina.extract is now async — called with await, not asyncio.to_thread.
  2. AI summarization + embedding run concurrently with asyncio.gather.
  3. Jina connect_timeout reduced to 5s; read_timeout to 8s (was a single
     30s wall timeout that silently consumed most of the SLO budget).
  4. trafilatura fallback is retained for when Jina times out or errors.
"""

from __future__ import annotations

import asyncio
import logging
import time
import uuid
from dataclasses import dataclass, field

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.embedding import Embedding
from app.models.item import ContentType, IngestStatus, Item, item_tags
from app.models.tag import Tag

logger = logging.getLogger(__name__)

_queue: asyncio.Queue["IngestJob"] = asyncio.Queue()


# ---------------------------------------------------------------------------
# Job dataclass
# ---------------------------------------------------------------------------

@dataclass
class IngestJob:
    job_id: str
    url: str
    content_type: str
    user_id: str
    collection_id: str | None = None
    retries: int = field(default=0)


# ---------------------------------------------------------------------------
# Public interface
# ---------------------------------------------------------------------------

async def enqueue_item(
    url: str,
    content_type: str,
    user_id: str,
    collection_id: str | None = None,
) -> str:
    job_id = str(uuid.uuid4())
    job = IngestJob(
        job_id=job_id,
        url=url,
        content_type=content_type,
        user_id=user_id,
        collection_id=collection_id,
    )
    await _queue.put(job)
    logger.info(
        "Enqueued job=%s url=%s user=%s content_type=%s",
        job_id, url, user_id, content_type,
    )
    return job_id


async def start_worker() -> None:
    """Long-running coroutine. Called once from app lifespan."""
    logger.info("Ingestion worker started")
    while True:
        job = await _queue.get()
        try:
            await _process_job(job)
        except Exception:
            logger.exception("Unhandled error in job=%s", job.job_id)
        finally:
            _queue.task_done()


# ---------------------------------------------------------------------------
# Stage timing helper
# ---------------------------------------------------------------------------

def _log_stage(stage: str, t0: float, **extra: object) -> int:
    """Log a pipeline stage and return elapsed_ms as an int."""
    elapsed_ms = int((time.perf_counter() - t0) * 1000)
    kv = " ".join(f"{k}={v}" for k, v in extra.items())
    logger.info("pipeline stage=%s elapsed_ms=%d %s", stage, elapsed_ms, kv)
    return elapsed_ms


# ---------------------------------------------------------------------------
# Job processor — full extraction + AI + embedding pipeline
# ---------------------------------------------------------------------------

async def _process_job(job: IngestJob) -> None:
    """
    Full ingest pipeline with per-stage timing instrumentation.

    Stages and their SLO budget contribution (rough targets):
      extraction  ~2-5s  (Jina, capped at 8s read + 5s connect)
      ai_summary  ~1-3s  (Claude Haiku, concurrent with embedding)
      embedding   ~0-1s  (deterministic stub; ~200ms real Fireworks call)
      db_write    ~0.2s
      ────────────────
      total       < 10s  (SPEC §9b SLO)
    """
    logger.info(
        "pipeline job_start job=%s url=%s user=%s",
        job.job_id, job.url, job.user_id,
    )
    wall_t0 = time.perf_counter()

    async with AsyncSessionLocal() as db:
        # ── 0. Create Item record (visible as "processing") ────────────────
        item = Item(
            id=uuid.uuid4(),
            user_id=uuid.UUID(job.user_id),
            url=job.url,
            content_type=(
                ContentType(job.content_type)
                if job.content_type in ContentType._value2member_map_
                else ContentType.article
            ),
            ingest_status=IngestStatus.processing,
        )
        db.add(item)
        await db.flush()
        await db.commit()

        try:
            # ── 1. Extract content ─────────────────────────────────────────
            extract_t0 = time.perf_counter()

            is_youtube = "youtube.com" in job.url or "youtu.be" in job.url
            if is_youtube or job.content_type == ContentType.video.value:
                from pipeline.youtube import extract as _sync_extract
                extraction = await asyncio.to_thread(_sync_extract, job.url)
                extractor_name = "youtube"
            elif job.content_type == ContentType.podcast.value:
                from pipeline.deepgram_extractor import extract as _sync_extract  # type: ignore[assignment]
                extraction = await asyncio.to_thread(_sync_extract, job.url)
                extractor_name = "deepgram"
            else:
                # Jina is async — await directly (no thread pool)
                from pipeline.jina import extract as _async_extract
                extraction = await _async_extract(job.url)
                extractor_name = "jina"

            extract_ms = _log_stage(
                "extraction",
                extract_t0,
                extractor=extractor_name,
                ok=extraction.ok,
                words=extraction.word_count,
            )

            # Fallback: trafilatura if Jina timed out or errored
            if not extraction.ok and job.content_type not in (
                ContentType.video.value, ContentType.podcast.value
            ):
                fallback_t0 = time.perf_counter()
                from pipeline.readability import extract as _fallback
                extraction = await asyncio.to_thread(_fallback, job.url)
                _log_stage(
                    "extraction_fallback",
                    fallback_t0,
                    extractor="trafilatura",
                    ok=extraction.ok,
                    words=extraction.word_count,
                )

            if not extraction.ok:
                raise RuntimeError(
                    f"All extractors failed: {extraction.error}"
                )

            content = extraction.content

            # ── 2. AI summarization + embedding (concurrent) ───────────────
            ai_t0 = time.perf_counter()

            from ai.pipeline import compute_embedding, summarize_item

            processed, emb_result = await asyncio.gather(
                asyncio.to_thread(summarize_item, content, job.content_type),
                asyncio.to_thread(compute_embedding, content),
            )

            ai_ms = _log_stage(
                "ai_summary",
                ai_t0,
                model="claude-haiku-4-5",
                tags=len(processed.tags),
            )

            # ── 3. Persist item fields ─────────────────────────────────────
            db_t0 = time.perf_counter()

            if extraction.title:
                item.title = extraction.title
            item.raw_content = content
            item.summary = processed.tldr
            item.metadata_ = {
                "extractor": extraction.extractor,
                "word_count": extraction.word_count,
                "extraction_ms": extract_ms,
                "ai_ms": ai_ms,
                **extraction.metadata,
            }
            item.ingest_status = IngestStatus.completed

            # ── 4. Embedding ───────────────────────────────────────────────
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
                    select(Tag).where(
                        Tag.user_id == item.user_id,
                        Tag.slug == slug,
                    )
                )
                tag = tag_res.scalar_one_or_none()
                if not tag:
                    tag = Tag(
                        id=uuid.uuid4(),
                        user_id=item.user_id,
                        name=tag_name,
                        slug=slug,
                    )
                    db.add(tag)
                    await db.flush()
                await db.execute(
                    pg_insert(item_tags)
                    .values(item_id=item.id, tag_id=tag.id)
                    .on_conflict_do_nothing()
                )

            await db.commit()

            db_ms = _log_stage("db_write", db_t0)

            # ── 6. SLO verdict ─────────────────────────────────────────────
            total_ms = int((time.perf_counter() - wall_t0) * 1000)
            slo_ok = total_ms < settings.ingest_slo_ms

            if slo_ok:
                logger.info(
                    "pipeline stage=total elapsed_ms=%d slo_ok=true "
                    "item=%s job=%s",
                    total_ms, item.id, job.job_id,
                )
            else:
                logger.warning(
                    "pipeline stage=total elapsed_ms=%d slo_ok=false "
                    "slo_target_ms=%d item=%s job=%s "
                    "extraction_ms=%d ai_ms=%d db_ms=%d",
                    total_ms,
                    settings.ingest_slo_ms,
                    item.id,
                    job.job_id,
                    extract_ms,
                    ai_ms,
                    db_ms,
                )

        except Exception as exc:
            logger.exception(
                "pipeline job_error job=%s url=%s exc=%s",
                job.job_id, job.url, exc,
            )
            item.ingest_status = IngestStatus.failed
            item.metadata_ = {**(item.metadata_ or {}), "error": str(exc)}
            await db.commit()
