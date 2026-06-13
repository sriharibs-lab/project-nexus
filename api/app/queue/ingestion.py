"""
Async content ingestion queue.

Currently an in-process asyncio queue. Replace the backend (Redis/Celery,
pgqueuer) without changing the public interface: enqueue_item / start_worker.
"""

import asyncio
import logging
import time
import uuid
from dataclasses import dataclass, field

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.core.database import AsyncSessionLocal
from app.models.ai_telemetry import AiTelemetry
from app.models.embedding import Embedding
from app.models.item import IngestStatus, Item, item_tags
from app.models.tag import Tag

logger = logging.getLogger(__name__)

_queue: asyncio.Queue["IngestJob"] = asyncio.Queue()


@dataclass
class IngestJob:
    item_id: uuid.UUID
    url: str
    content_type: str
    user_id: uuid.UUID
    retries: int = field(default=0)


async def enqueue_item(item_id: uuid.UUID, url: str, content_type: str, user_id: uuid.UUID) -> None:
    job = IngestJob(item_id=item_id, url=url, content_type=content_type, user_id=user_id)
    await _queue.put(job)
    logger.info("Enqueued item_id=%s url=%s", item_id, url)


async def _process_job(job: IngestJob) -> None:
    logger.info("Processing item_id=%s url=%s", job.item_id, job.url)

    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Item).where(Item.id == job.item_id))
        item = result.scalar_one_or_none()
        if not item:
            logger.error("Item %s not found — skipping", job.item_id)
            return

        item.ingest_status = IngestStatus.processing
        await db.commit()

        t0 = time.perf_counter()
        try:
            # ── 1. Extract content ─────────────────────────────────────────
            url = job.url
            ct = job.content_type

            if "youtube.com" in url or "youtu.be" in url or ct == "video":
                from pipeline.youtube import extract as _extract
            elif ct == "podcast":
                from pipeline.deepgram_extractor import extract as _extract  # type: ignore[assignment]
            else:
                from pipeline.jina import extract as _extract  # type: ignore[assignment]

            extraction = await asyncio.to_thread(_extract, url)

            # Fall back to trafilatura if primary failed
            if not extraction.ok and ct not in ("video", "podcast"):
                from pipeline.readability import extract as _fallback
                extraction = await asyncio.to_thread(_fallback, url)

            if not extraction.ok:
                raise RuntimeError(f"Extraction failed: {extraction.error}")

            content = extraction.content

            # ── 2. AI summarization ────────────────────────────────────────
            from ai.pipeline import compute_embedding, summarize_item

            ai_t0 = time.perf_counter()
            processed = await summarize_item(content, ct)  # type: ignore[arg-type]
            ai_ms = int((time.perf_counter() - ai_t0) * 1000)

            emb_t0 = time.perf_counter()
            emb_result = await compute_embedding(content)
            emb_ms = int((time.perf_counter() - emb_t0) * 1000)

            # ── 3. Update item ─────────────────────────────────────────────
            if extraction.title and not item.title:
                item.title = extraction.title
            item.raw_content = content
            item.summary = processed.tldr
            item.metadata_ = {
                **(item.metadata_ or {}),
                "insights": processed.insights,
                "extractor": extraction.extractor,
                "word_count": extraction.word_count,
                "extraction_ms": int(extraction.elapsed_ms),
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
                    select(Tag).where(Tag.user_id == item.user_id, Tag.slug == slug)
                )
                tag = tag_res.scalar_one_or_none()
                if not tag:
                    tag = Tag(id=uuid.uuid4(), user_id=item.user_id, name=tag_name, slug=slug)
                    db.add(tag)
                    await db.flush()  # get tag.id before insert below
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
                correlation_id=str(job.item_id),
                operation="summarize",
                model=processed.model,
                input_tokens=processed.input_tokens,
                output_tokens=processed.output_tokens,
                cache_read_tokens=processed.cache_read_tokens,
                cost_usd=processed.cost_usd + emb_result.cost_usd,
                duration_ms=ai_ms + emb_ms,
            ))

            await db.commit()
            total_ms = int((time.perf_counter() - t0) * 1000)
            logger.info("Item completed item_id=%s total_ms=%d", job.item_id, total_ms)

        except Exception as exc:
            logger.exception("Item failed item_id=%s: %s", job.item_id, exc)
            item.ingest_status = IngestStatus.failed
            item.metadata_ = {**(item.metadata_ or {}), "error": str(exc)}
            await db.commit()


async def start_worker() -> None:
    logger.info("Ingestion worker started")
    while True:
        job = await _queue.get()
        try:
            await _process_job(job)
        except Exception:
            logger.exception("Unhandled error processing job item_id=%s", job.item_id)
        finally:
            _queue.task_done()
