"""
Nexus API — FastAPI application entry point.

Deploy target: app.main:app   (i.e.  uvicorn app.main:app)
A Procfile at api/Procfile pins this explicitly to prevent misconfigured
deploys from accidentally loading the skeleton api/main.py stub instead.
"""

import asyncio
import logging
from contextlib import asynccontextmanager
from collections.abc import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.queue.ingestion import close_pgq_pool, init_pgq_pool, start_worker
from app.routers import auth, feedback, health, ingest, collections, items, research

logging.basicConfig(level=settings.log_level.upper())
logger = logging.getLogger(__name__)

_worker_task: asyncio.Task | None = None


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    global _worker_task
    logger.info("Nexus API starting — environment=%s", settings.environment)

    # Initialise pgqueuer pool BEFORE starting the worker.
    # get_pgq_pool() raises RuntimeError if this is skipped.
    await init_pgq_pool()

    _worker_task = asyncio.create_task(start_worker())

    yield

    # Graceful shutdown: cancel worker first, then drain pool.
    if _worker_task:
        _worker_task.cancel()
        try:
            await _worker_task
        except asyncio.CancelledError:
            pass
    await close_pgq_pool()
    logger.info("Nexus API shut down")


app = FastAPI(
    title="Nexus API",
    description="AI-native content curation platform",
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs" if not settings.is_production else None,
    redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if not settings.is_production else [],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(auth.router, prefix="/v1")
app.include_router(feedback.router, prefix="/v1")
app.include_router(ingest.router, prefix="/v1")
app.include_router(collections.router, prefix="/v1")
app.include_router(items.router, prefix="/v1")
app.include_router(research.router, prefix="/v1")
