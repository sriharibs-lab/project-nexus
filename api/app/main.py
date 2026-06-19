import asyncio
import logging
from contextlib import asynccontextmanager
from collections.abc import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.queue.ingestion import start_worker
from app.routers import auth, feedback, health, ingest, collections, items, research

logging.basicConfig(level=settings.log_level.upper())
logger = logging.getLogger(__name__)

_worker_task: asyncio.Task | None = None


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    global _worker_task
    _worker_task = asyncio.create_task(start_worker())
    logger.info("Nexus API starting — environment=%s", settings.environment)
    yield
    if _worker_task:
        _worker_task.cancel()
        try:
            await _worker_task
        except asyncio.CancelledError:
            pass
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
