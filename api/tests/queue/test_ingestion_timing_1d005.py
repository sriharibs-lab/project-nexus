"""
Tests for app/queue/ingestion.py — 1D-005 timing and SLO instrumentation.

Coverage:
  - Stage timing logs emitted (extraction, ai_summary, db_write, total).
  - slo_ok=true appears in total log for a fast job.
  - jina.extract is awaited directly (not via asyncio.to_thread).
  - asyncio.gather used for concurrent AI steps.
  - enqueue_item returns a job_id string.
"""

from __future__ import annotations

import asyncio
import enum
import importlib
import inspect
import logging
import os
import sys
import types
import unittest
import uuid
from dataclasses import dataclass, field
from unittest.mock import MagicMock

# ---------------------------------------------------------------------------
# Ensure the api/ directory is on sys.path so real modules can be imported.
# ---------------------------------------------------------------------------
_API_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
if _API_DIR not in sys.path:
    sys.path.insert(0, _API_DIR)


# ---------------------------------------------------------------------------
# Heavy dependency stubs — must be installed before ingestion.py is imported.
# ---------------------------------------------------------------------------

def _make_content_type() -> type:
    class ContentType(str, enum.Enum):
        article = "article"
        podcast = "podcast"
        video = "video"
        thread = "thread"
        blog = "blog"
        announcement = "announcement"
        other = "other"
    return ContentType


def _make_ingest_status() -> type:
    class IngestStatus(str, enum.Enum):
        pending = "pending"
        processing = "processing"
        completed = "completed"
        failed = "failed"
    return IngestStatus


def _install_db_stubs(ContentType, IngestStatus) -> None:
    """Install all database and model stubs so ingestion.py can be imported."""

    class FakeItem:
        def __init__(self, **kwargs):
            self.id = uuid.uuid4()
            self.user_id = kwargs.get("user_id")
            self.url = kwargs.get("url", "")
            self.content_type = kwargs.get("content_type", ContentType.article)
            self.ingest_status = kwargs.get("ingest_status", IngestStatus.pending)
            self.title = None
            self.raw_content = None
            self.summary = None
            self.metadata_ = {}

    class FakeColumnExpr:
        """Supports SQLAlchemy-style column == value expressions on the class."""
        def __eq__(self, other):
            return MagicMock()
        def __hash__(self):
            return id(self)

    class FakeTagMeta(type):
        """Metaclass that returns a FakeColumnExpr for any class-level attr access."""
        def __getattr__(cls, name):
            return FakeColumnExpr()

    class FakeTag(metaclass=FakeTagMeta):
        def __init__(self, **kwargs):
            self.id = uuid.uuid4()
            self.user_id = kwargs.get("user_id")
            self.name = kwargs.get("name", "")
            self.slug = kwargs.get("slug", "")

    class FakeEmbedding:
        def __init__(self, **kwargs):
            self.id = uuid.uuid4()
            self.item_id = kwargs.get("item_id")
            self.embedding = kwargs.get("embedding", [])
            self.model = kwargs.get("model", "stub")
            self.dimensions = kwargs.get("dimensions", 1536)

    item_tags = MagicMock(name="item_tags")

    fake_settings = types.SimpleNamespace(
        ingest_slo_ms=10_000,
        jina_timeout=8,
        jina_fallback_to_readability=True,
    )

    # --- DB session ---
    class FakeDB:
        def __init__(self):
            self.added = []

        def add(self, obj):
            self.added.append(obj)

        async def flush(self):
            pass

        async def commit(self):
            pass

        async def execute(self, stmt):
            result = MagicMock()
            result.scalar_one_or_none.return_value = None
            return result

        async def __aenter__(self):
            return self

        async def __aexit__(self, *a):
            pass

    class _SessionCtx:
        async def __aenter__(self):
            return FakeDB()

        async def __aexit__(self, *a):
            pass

    class AsyncSessionLocal:
        def __call__(self):
            return _SessionCtx()

    def fake_pg_insert(table):
        ins = MagicMock()
        ins.values.return_value.on_conflict_do_nothing.return_value = MagicMock()
        return ins

    def fake_select(*args, **kwargs):
        m = MagicMock()
        m.where = MagicMock(return_value=MagicMock())
        return m

    # --- Build module objects ---
    stub_item_mod = types.ModuleType("app.models.item")
    stub_item_mod.ContentType = ContentType
    stub_item_mod.IngestStatus = IngestStatus
    stub_item_mod.Item = FakeItem
    stub_item_mod.item_tags = item_tags

    stub_tag_mod = types.ModuleType("app.models.tag")
    stub_tag_mod.Tag = FakeTag

    stub_emb_mod = types.ModuleType("app.models.embedding")
    stub_emb_mod.Embedding = FakeEmbedding

    stub_config_mod = types.ModuleType("app.core.config")
    stub_config_mod.settings = fake_settings

    stub_db_mod = types.ModuleType("app.core.database")
    stub_db_mod.AsyncSessionLocal = AsyncSessionLocal()

    stub_sa = types.ModuleType("sqlalchemy")
    stub_sa.select = fake_select
    stub_sa.update = MagicMock(return_value=MagicMock(
        where=MagicMock(return_value=MagicMock(
            values=MagicMock(return_value=MagicMock())
        ))
    ))

    stub_sa_dialects = types.ModuleType("sqlalchemy.dialects")
    stub_sa_pg = types.ModuleType("sqlalchemy.dialects.postgresql")
    stub_sa_pg.insert = fake_pg_insert

    stub_sa_ext = types.ModuleType("sqlalchemy.ext")
    stub_sa_ext_asyncio = types.ModuleType("sqlalchemy.ext.asyncio")
    stub_sa_ext_asyncio.AsyncSession = object  # type hint only

    # Make sure app.* namespace exists as real package objects (not bare ModuleType)
    # app and app.models are real packages on disk — keep them or create minimal stubs
    if "app" not in sys.modules:
        app_mod = types.ModuleType("app")
        app_mod.__path__ = [os.path.join(_API_DIR, "app")]
        app_mod.__package__ = "app"
        sys.modules["app"] = app_mod

    if "app.models" not in sys.modules:
        models_mod = types.ModuleType("app.models")
        models_mod.__path__ = [os.path.join(_API_DIR, "app", "models")]
        models_mod.__package__ = "app.models"
        sys.modules["app.models"] = models_mod

    if "app.core" not in sys.modules:
        core_mod = types.ModuleType("app.core")
        core_mod.__path__ = [os.path.join(_API_DIR, "app", "core")]
        core_mod.__package__ = "app.core"
        sys.modules["app.core"] = core_mod

    if "app.queue" not in sys.modules:
        queue_mod = types.ModuleType("app.queue")
        queue_mod.__path__ = [os.path.join(_API_DIR, "app", "queue")]
        queue_mod.__package__ = "app.queue"
        sys.modules["app.queue"] = queue_mod

    # Override the heavy dependency modules with stubs
    sys.modules["app.models.item"] = stub_item_mod
    sys.modules["app.models.tag"] = stub_tag_mod
    sys.modules["app.models.embedding"] = stub_emb_mod
    sys.modules["app.core.config"] = stub_config_mod
    sys.modules["app.core.database"] = stub_db_mod
    sys.modules["sqlalchemy"] = stub_sa
    sys.modules["sqlalchemy.dialects"] = stub_sa_dialects
    sys.modules["sqlalchemy.dialects.postgresql"] = stub_sa_pg
    sys.modules["sqlalchemy.ext"] = stub_sa_ext
    sys.modules["sqlalchemy.ext.asyncio"] = stub_sa_ext_asyncio


def _install_pipeline_stubs() -> None:
    """Install pipeline.jina and ai.pipeline stubs (fast, no network)."""

    @dataclass
    class FakeExtraction:
        ok: bool = True
        content: str = "Article text about machine learning."
        title: str = "Test Article"
        word_count: int = 6
        elapsed_ms: float = 120.0
        error: str | None = None
        extractor: str = "Jina AI Reader"
        metadata: dict = field(default_factory=dict)

    @dataclass
    class FakeProcessed:
        tldr: str = "Quick summary."
        insights: list = field(default_factory=lambda: ["Insight A"])
        tags: list = field(default_factory=lambda: ["ai", "ml"])

    @dataclass
    class FakeEmbeddingResult:
        vector: list = field(default_factory=lambda: [0.1] * 1536)
        dimensions: int = 1536
        model: str = "stub-sha256-1536"

    async def fake_jina_extract(url: str) -> FakeExtraction:
        return FakeExtraction()

    def fake_summarize(content: str, ct: str) -> FakeProcessed:
        return FakeProcessed()

    def fake_embed(content: str) -> FakeEmbeddingResult:
        return FakeEmbeddingResult()

    def fake_readability_extract(url: str) -> FakeExtraction:
        return FakeExtraction(extractor="trafilatura")

    def fake_youtube_extract(url: str, language: str = "en") -> FakeExtraction:
        return FakeExtraction(extractor="youtube")

    def fake_deepgram_extract(url: str) -> FakeExtraction:
        return FakeExtraction(extractor="deepgram")

    # Ensure pipeline package stubs exist
    if "pipeline" not in sys.modules:
        pipeline_pkg = types.ModuleType("pipeline")
        pipeline_pkg.__path__ = [os.path.join(_API_DIR, "pipeline")]
        pipeline_pkg.__package__ = "pipeline"
        sys.modules["pipeline"] = pipeline_pkg

    if "ai" not in sys.modules:
        ai_pkg = types.ModuleType("ai")
        ai_pkg.__path__ = [os.path.join(_API_DIR, "ai")]
        ai_pkg.__package__ = "ai"
        sys.modules["ai"] = ai_pkg

    jina_mod = types.ModuleType("pipeline.jina")
    jina_mod.extract = fake_jina_extract

    ai_mod = types.ModuleType("ai.pipeline")
    ai_mod.summarize_item = fake_summarize
    ai_mod.compute_embedding = fake_embed

    rb_mod = types.ModuleType("pipeline.readability")
    rb_mod.extract = fake_readability_extract

    yt_mod = types.ModuleType("pipeline.youtube")
    yt_mod.extract = fake_youtube_extract

    dg_mod = types.ModuleType("pipeline.deepgram_extractor")
    dg_mod.extract = fake_deepgram_extract

    sys.modules["pipeline.jina"] = jina_mod
    sys.modules["ai.pipeline"] = ai_mod
    sys.modules["pipeline.readability"] = rb_mod
    sys.modules["pipeline.youtube"] = yt_mod
    sys.modules["pipeline.deepgram_extractor"] = dg_mod


# --- Install stubs at module load time ---
_ContentType = _make_content_type()
_IngestStatus = _make_ingest_status()
_install_db_stubs(_ContentType, _IngestStatus)
_install_pipeline_stubs()


def _import_ingestion():
    """Import (or re-import) app.queue.ingestion with current stubs."""
    # Remove cached version to force fresh import
    sys.modules.pop("app.queue.ingestion", None)
    import importlib
    import app.queue.ingestion as mod
    return mod


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def _read_ingestion_source() -> str:
    """Read ingestion.py source directly without importing (avoids event loop issues)."""
    src_path = os.path.join(_API_DIR, "app", "queue", "ingestion.py")
    with open(src_path) as f:
        return f.read()


class TestJinaNotWrappedInToThread(unittest.TestCase):
    """
    jina.extract is async — it must be awaited directly, NOT via asyncio.to_thread.
    Passing a coroutine to to_thread() silently passes the coroutine object
    to a thread without executing it, resulting in no content being extracted.

    We verify by reading the source file directly (no import = no event loop issue).
    """

    def test_jina_extract_awaited_not_threaded(self):
        source = _read_ingestion_source()
        # The async jina extractor must be aliased as _async_extract
        self.assertIn(
            "_async_extract",
            source,
            "_process_job must assign the async Jina extractor to _async_extract.",
        )
        # It must NOT be wrapped in asyncio.to_thread
        self.assertNotIn(
            "to_thread(_async_extract",
            source,
            "jina.extract is async — must be awaited, not passed to to_thread.",
        )

    def test_gather_used_for_ai_steps(self):
        """summarize + embed should run concurrently via asyncio.gather."""
        source = _read_ingestion_source()
        self.assertIn(
            "asyncio.gather",
            source,
            "summarize_item and compute_embedding should run concurrently "
            "via asyncio.gather() to save 1-2s per ingest job.",
        )


class TestStageLogs(unittest.IsolatedAsyncioTestCase):
    """_process_job must emit structured stage logs for each pipeline phase."""

    async def _run_and_capture_logs(self, slo_ms: int = 10_000) -> list[logging.LogRecord]:
        mod = _import_ingestion()

        # Temporarily override slo target
        import app.core.config as cfg_mod
        old_slo = cfg_mod.settings.ingest_slo_ms
        cfg_mod.settings.ingest_slo_ms = slo_ms

        records: list[logging.LogRecord] = []

        class CapturingHandler(logging.Handler):
            def emit(self, record):
                records.append(record)

        handler = CapturingHandler()
        logger = logging.getLogger("app.queue.ingestion")
        logger.addHandler(handler)
        logger.setLevel(logging.DEBUG)

        try:
            job = mod.IngestJob(
                job_id="test-stage-001",
                url="https://example.com/article",
                content_type="article",
                user_id=str(uuid.uuid4()),
            )
            await mod._process_job(job)
        finally:
            logger.removeHandler(handler)
            cfg_mod.settings.ingest_slo_ms = old_slo

        return records

    async def test_all_stages_logged(self):
        records = await self._run_and_capture_logs()
        messages = [r.getMessage() for r in records]

        for stage in ["extraction", "ai_summary", "db_write", "total"]:
            self.assertTrue(
                any(f"stage={stage}" in m for m in messages),
                f"Expected 'stage={stage}' in log. Got: {[m for m in messages if 'stage' in m]}",
            )

    async def test_slo_ok_true_for_fast_job(self):
        """With mocked IO completing in <1ms, slo_ok=true must be logged."""
        records = await self._run_and_capture_logs(slo_ms=10_000)
        messages = [r.getMessage() for r in records]

        total_msg = next((m for m in messages if "stage=total" in m), None)
        self.assertIsNotNone(total_msg, "stage=total log must exist.")
        self.assertIn(
            "slo_ok=true", total_msg,
            f"Expected slo_ok=true in: {total_msg}",
        )

    async def test_elapsed_ms_in_extraction_log(self):
        records = await self._run_and_capture_logs()
        messages = [r.getMessage() for r in records]
        ext_msg = next((m for m in messages if "stage=extraction" in m), None)
        self.assertIsNotNone(ext_msg, "stage=extraction log must exist.")
        self.assertIn("elapsed_ms=", ext_msg)

    async def test_slo_breach_logs_warning(self):
        """When SLO target is 0ms, slo_ok=false must appear at WARNING level."""
        records = await self._run_and_capture_logs(slo_ms=0)

        warning_records = [
            r for r in records
            if r.levelno >= logging.WARNING and "slo_ok=false" in r.getMessage()
        ]
        self.assertGreater(
            len(warning_records), 0,
            "Expected WARNING with 'slo_ok=false' when slo_ms=0. "
            f"All messages: {[r.getMessage() for r in records]}",
        )


class TestEnqueueItem(unittest.IsolatedAsyncioTestCase):
    """enqueue_item public interface."""

    async def test_returns_string_job_id(self):
        mod = _import_ingestion()
        job_id = await mod.enqueue_item(
            url="https://example.com/article",
            content_type="article",
            user_id=str(uuid.uuid4()),
        )
        self.assertIsInstance(job_id, str)
        self.assertGreater(len(job_id), 0)

    async def test_accepts_collection_id_kwarg(self):
        mod = _import_ingestion()
        job_id = await mod.enqueue_item(
            url="https://example.com/article",
            content_type="article",
            user_id=str(uuid.uuid4()),
            collection_id=str(uuid.uuid4()),
        )
        self.assertIsInstance(job_id, str)


if __name__ == "__main__":
    unittest.main()
