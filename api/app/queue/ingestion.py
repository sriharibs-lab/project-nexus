"""
Async content ingestion queue stub.

Currently an in-process asyncio queue. Replace the backend (Redis/BullMQ,
Celery, or a Postgres-backed queue like pgqueuer) without changing the
public interface: enqueue_item / start_worker.
"""

import asyncio
import logging
import uuid
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)

_queue: asyncio.Queue["IngestJob"] = asyncio.Queue()


@dataclass
class IngestJob:
    job_id: str
    url: str
    content_type: str
    user_id: str
    retries: int = field(default=0)


async def enqueue_item(url: str, content_type: str, user_id: str) -> str:
    job_id = str(uuid.uuid4())
    job = IngestJob(job_id=job_id, url=url, content_type=content_type, user_id=user_id)
    await _queue.put(job)
    logger.info("Enqueued job %s for url=%s user=%s", job_id, url, user_id)
    return job_id


async def _process_job(job: IngestJob) -> None:
    """
    Stub processor — replace with real fetch → parse → embed → store pipeline.
    """
    logger.info("Processing job %s url=%s", job.job_id, job.url)
    # TODO: fetch content, extract text, generate embedding, persist Item + Embedding
    await asyncio.sleep(0)  # yield to event loop


async def start_worker() -> None:
    """
    Long-running coroutine. Called once from app lifespan.
    """
    logger.info("Ingestion worker started")
    while True:
        job = await _queue.get()
        try:
            await _process_job(job)
        except Exception:
            logger.exception("Failed to process job %s", job.job_id)
        finally:
            _queue.task_done()
