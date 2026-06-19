"""
Async content ingestion queue.

Currently an in-process asyncio queue. Replace the backend (Redis/Celery,
pgqueuer) without changing the public interface: enqueue_item / start_worker.

NOTE: In-process queue loses all jobs on crash or redeploy. Swap to pgqueuer
or Redis before Phase 1C / TestFlight cutoff (Architect note).
"""

import asyncio
import logging
import time
import uuid
from dataclasses import dataclass, field

from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.core.database import AsyncSessionLocal
from app.models.ai_telemetry import AiTelemetry
from app.models.collection import Collection
from app.models.embedding import Embedding
from app.models.item import ContentType, IngestStatus, Item, collection_items, item_tags
from app.models.tag import Tag

logger = logging.getLogger(__name__)

_queue: asyncio.Queue["IngestJob"] = asyncio.Queue()


@dataclass
class IngestJob:
    job_id: str
    url: str
    content_type: str
    user_id: str
    collection_id: str
    retries: int = field(default=0)


async def enqueue_item(url: str, content_type: str, user_id: str, collection_id: str) -> str:
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
        "Enqueued job %s for url=%s user=%s collection=%s",
        job_id, url, user_id, collection_id,
    )
    return job_id


async def _process_job(job: IngestJob) -> None:
    logger.info("Processing job %s url=%s collection=%s", job.job_id, job.url, job.collection_id)

    async with AsyncSessionLocal() as db:
        t0 = time.perf_counter()

        # Create item record (no collection_id FK — membership via collection_items)
        item = Item(
            id=uuid.uuid4(),
            user_id=uuid.UUID(job.user_id),
            url=job.url,
            content_type=ContentType(job.content_type) if job.content_type in ContentType._value2member_map_ else ContentType.article,
            ingest_status=IngestStatus.processing,
        )
        db.add(item)
        await db.flush()  # get item.id without committing

        # Wire item into collection via join table (visible immediately as processing)
        collection_id = uuid.UUID(job.collection_id)
        await db.execute(
            pg_insert(collection_items)
            .values(collection_id=collection_id, item_id=item.id)
            .on_conflict_do_nothing()
        )
        await db.commit()

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
            if extraction.title:
                item.title = extraction.title
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

            # Increment source_count only on success — avoids phantom counts on failure
            await db.execute(
                update(Collection)
                .where(Collection.id == collection_id)
                .values(source_count=Collection.source_count + 1)
            )

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
                correlation_id=job.job_id,
                operation="summarize",
                model=processed.model,
                input_tokens=processed.input_tokens,
                output_tokens=processed.output_tokens,
                cache_read_tokens=processed.cache_read_tokens,
                cost_usd=processed.cost_usd + emb_result.cost_usd,
                duration_ms=ai_ms + emb_ms,
            ))

            await db.commit()

            # ── 7. Framing paragraph (first source only) ───────────────────
            # Generates the Nexus-tab hero sentence after the very first item
            # in a collection completes, so the tab is never blank.
            try:
                from sqlalchemy import func as sqlfunc
                completed_count_result = await db.execute(
                    select(sqlfunc.count()).select_from(Item)
                    .join(collection_items, collection_items.c.item_id == Item.id)
                    .where(
                        collection_items.c.collection_id == collection_id,
                        Item.ingest_status == IngestStatus.completed,
                    )
                )
                if completed_count_result.scalar() == 1 and item.summary:
                    col_res = await db.execute(
                        select(Collection).where(Collection.id == collection_id)
                    )
                    col = col_res.scalar_one_or_none()
                    if col and not col.framing_paragraph:
                        from ai.pipeline import build_collection_framing
                        col.framing_paragraph = await build_collection_framing(col.name, item.summary)
                        await db.commit()
            except Exception as framing_exc:
                logger.warning("Framing generation failed for collection %s: %s", collection_id, framing_exc)

            total_ms = int((time.perf_counter() - t0) * 1000)
            logger.info("Job completed item_id=%s total_ms=%d", item.id, total_ms)

        except Exception as exc:
            logger.exception("Job failed %s: %s", job.job_id, exc)
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
            logger.exception("Unhandled error processing job %s", job.job_id)
        finally:
            _queue.task_done()
