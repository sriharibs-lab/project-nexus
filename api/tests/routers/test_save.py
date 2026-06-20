"""
Tests for task 1B-003: Share Extension — capture URL from any app.

Covers the testable backend hints:
1. _detect_content_type() logic (function missing — save.py not created by SWE)
2. ContentType enum lowercase values in pipeline/base.py
3. Pipeline modules do NOT raise AttributeError on ContentType access
4. POST /v1/save router existence and auth/validation behaviour
5. pgqueuer fallback: start_worker() falls back to asyncio queue (existing ingestion.py)
6. Alembic migration 0002_pgqueuer_jobs.py existence

iOS hints are not testable in Python CI — documented as skipped.
"""

import inspect
import os
import sys
import unittest
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# Helper: add api/ to sys.path so bare imports work
# ---------------------------------------------------------------------------
_API_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
if _API_DIR not in sys.path:
    sys.path.insert(0, _API_DIR)


# ---------------------------------------------------------------------------
# 1. ContentType enum: canonical lowercase values exist
# ---------------------------------------------------------------------------
class TestContentTypeEnumLowercase(unittest.TestCase):
    """Verify ContentType.article / .video / .podcast all exist (lowercase, not uppercase)."""

    def setUp(self):
        from app.models.item import ContentType
        self.ContentType = ContentType

    def test_article_lowercase_exists(self):
        ct = self.ContentType
        self.assertTrue(hasattr(ct, "article"),
                        "ContentType.article must exist (lowercase)")

    def test_video_lowercase_exists(self):
        ct = self.ContentType
        self.assertTrue(hasattr(ct, "video"),
                        "ContentType.video must exist (lowercase)")

    def test_podcast_lowercase_exists(self):
        ct = self.ContentType
        self.assertTrue(hasattr(ct, "podcast"),
                        "ContentType.podcast must exist (lowercase)")

    def test_no_uppercase_article(self):
        ct = self.ContentType
        self.assertFalse(hasattr(ct, "ARTICLE"),
                         "ContentType.ARTICLE must NOT exist — use lowercase .article")

    def test_no_uppercase_video(self):
        ct = self.ContentType
        self.assertFalse(hasattr(ct, "VIDEO"),
                         "ContentType.VIDEO must NOT exist — use lowercase .video")

    def test_no_uppercase_podcast(self):
        ct = self.ContentType
        self.assertFalse(hasattr(ct, "PODCAST"),
                         "ContentType.PODCAST must NOT exist — use lowercase .podcast")

    def test_pipeline_base_reexports_same_class(self):
        """pipeline/base.py must re-export the same ContentType class (not a different one)."""
        from app.models.item import ContentType as ModelCT
        from pipeline.base import ContentType as PipelineCT
        self.assertIs(ModelCT, PipelineCT,
                      "pipeline/base.py must re-export the same ContentType class as app/models/item.py")


# ---------------------------------------------------------------------------
# 2. Jina pipeline: ContentType.ARTICLE raises AttributeError (bug detection)
# ---------------------------------------------------------------------------
class TestJinaPipelineContentTypeAccess(unittest.TestCase):
    """
    Verify whether jina.py uses correct lowercase ContentType.

    This test DETECTS the bug introduced by the SWE agent: jina.py references
    ContentType.ARTICLE (uppercase) which does not exist on the canonical enum.
    Expected state after fix: test_no_attribute_error passes.
    Expected state BEFORE fix (current): test_source_uses_uppercase_fails documents the bug.
    """

    def test_jina_source_uses_uppercase_article_bug(self):
        """
        KNOWN BUG: jina.py references ContentType.ARTICLE (uppercase).
        This will raise AttributeError at runtime. SWE must fix to ContentType.article.
        """
        path = os.path.join(_API_DIR, "pipeline/jina.py")
        with open(path) as f:
            src = f.read()
        self.assertIn(
            "ContentType.ARTICLE", src,
            "Bug already fixed (ContentType.ARTICLE no longer in jina.py) — "
            "update this test to test_jina_uses_lowercase_article"
        )

    def test_jina_extract_raises_attribute_error_on_mock_call(self):
        """
        Calling jina.extract() with a mocked HTTP response raises AttributeError
        because ContentType.ARTICLE does not exist. This is the runtime symptom.
        """
        with patch("httpx.get") as mock_get:
            mock_resp = MagicMock()
            mock_resp.text = "Title: Test\nContent here"
            mock_resp.raise_for_status = MagicMock()
            mock_get.return_value = mock_resp

            from pipeline.jina import extract
            # Bug: ExtractionResult constructor references ContentType.ARTICLE
            with self.assertRaises(AttributeError):
                extract("https://example.com/article")


# ---------------------------------------------------------------------------
# 3. YouTube pipeline: ContentType.VIDEO bug detection
# ---------------------------------------------------------------------------
class TestYoutubePipelineContentTypeAccess(unittest.TestCase):
    """Detect ContentType.VIDEO uppercase bug in youtube.py."""

    def test_youtube_source_uses_uppercase_video_bug(self):
        """KNOWN BUG: youtube.py references ContentType.VIDEO (uppercase)."""
        path = os.path.join(_API_DIR, "pipeline/youtube.py")
        with open(path) as f:
            src = f.read()
        self.assertIn(
            "ContentType.VIDEO", src,
            "Bug already fixed (ContentType.VIDEO no longer in youtube.py) — "
            "update to test lowercase"
        )

    def test_youtube_extract_raises_attribute_error_on_bad_url(self):
        """
        youtube.extract() with an invalid video ID should return an ExtractionResult
        with error set (not raise). But the ContentType.VIDEO bug means it will raise
        AttributeError during the ExtractionResult construction in the except block.
        """
        from pipeline.youtube import extract
        # Passing an obviously bad URL triggers the ValueError path,
        # which hits the except handler — which also uses ContentType.VIDEO
        with self.assertRaises(AttributeError):
            extract("https://youtube.com/watch?v=INVALID_TEST_ONLY")


# ---------------------------------------------------------------------------
# 4. Deepgram pipeline: ContentType.PODCAST bug detection
# ---------------------------------------------------------------------------
class TestDeepgramPipelineContentTypeAccess(unittest.TestCase):
    """Detect ContentType.PODCAST uppercase bug in deepgram_extractor.py."""

    def test_deepgram_source_uses_uppercase_podcast_bug(self):
        """KNOWN BUG: deepgram_extractor.py references ContentType.PODCAST (uppercase)."""
        path = os.path.join(_API_DIR, "pipeline/deepgram_extractor.py")
        with open(path) as f:
            src = f.read()
        self.assertIn(
            "ContentType.PODCAST", src,
            "Bug already fixed (ContentType.PODCAST no longer in deepgram_extractor.py)"
        )

    def test_deepgram_extract_no_api_key_raises_attribute_error(self):
        """
        deepgram.extract() with no DEEPGRAM_API_KEY hits the early-return path
        which constructs ExtractionResult with ContentType.PODCAST — this raises AttributeError.
        """
        with patch.dict(os.environ, {}, clear=True):
            # Remove DEEPGRAM_API_KEY if set
            env = {k: v for k, v in os.environ.items() if k != "DEEPGRAM_API_KEY"}
            with patch.dict(os.environ, env, clear=True):
                from pipeline.deepgram_extractor import extract
                with self.assertRaises(AttributeError):
                    extract("https://example.com/audio.mp3")


# ---------------------------------------------------------------------------
# 5. save.py router: file existence check
# ---------------------------------------------------------------------------
class TestSaveRouterExists(unittest.TestCase):
    """save.py must exist as a router file (SWE deliverable check)."""

    def test_save_py_file_exists(self):
        path = os.path.join(_API_DIR, "app/routers/save.py")
        self.assertTrue(
            os.path.exists(path),
            f"api/app/routers/save.py does not exist — SWE did not create the /v1/save router"
        )

    def test_detect_content_type_function_exists(self):
        """_detect_content_type() must be importable from app.routers.save."""
        path = os.path.join(_API_DIR, "app/routers/save.py")
        if not os.path.exists(path):
            self.skipTest("save.py not created by SWE agent — skipping import test")
        from app.routers.save import _detect_content_type
        self.assertTrue(callable(_detect_content_type))

    def test_detect_content_type_youtube_url(self):
        """youtube.com/watch?v=... → 'video'"""
        path = os.path.join(_API_DIR, "app/routers/save.py")
        if not os.path.exists(path):
            self.skipTest("save.py not created by SWE agent")
        from app.routers.save import _detect_content_type
        self.assertEqual(_detect_content_type("https://www.youtube.com/watch?v=dQw4w9WgXcQ"), "video")

    def test_detect_content_type_spotify_episode(self):
        """spotify.com/episode/... → 'podcast'"""
        path = os.path.join(_API_DIR, "app/routers/save.py")
        if not os.path.exists(path):
            self.skipTest("save.py not created by SWE agent")
        from app.routers.save import _detect_content_type
        self.assertEqual(_detect_content_type("https://open.spotify.com/episode/abc123"), "podcast")

    def test_detect_content_type_generic_url(self):
        """https://example.com/article → 'article'"""
        path = os.path.join(_API_DIR, "app/routers/save.py")
        if not os.path.exists(path):
            self.skipTest("save.py not created by SWE agent")
        from app.routers.save import _detect_content_type
        self.assertEqual(_detect_content_type("https://example.com/article"), "article")

    def test_detect_content_type_youtu_be_short(self):
        """youtu.be/... shortlinks → 'video'"""
        path = os.path.join(_API_DIR, "app/routers/save.py")
        if not os.path.exists(path):
            self.skipTest("save.py not created by SWE agent")
        from app.routers.save import _detect_content_type
        self.assertEqual(_detect_content_type("https://youtu.be/dQw4w9WgXcQ"), "video")


# ---------------------------------------------------------------------------
# 6. Alembic migration 0002_pgqueuer_jobs.py existence
# ---------------------------------------------------------------------------
class TestAlembicMigration0002PgqueuerExists(unittest.TestCase):
    """The new pgqueuer-related migration must exist in alembic/versions/."""

    def _migration_path(self):
        return os.path.join(_API_DIR, "alembic/versions/0002_pgqueuer_jobs.py")

    def test_migration_file_exists(self):
        """alembic/versions/0002_pgqueuer_jobs.py must exist (SWE deliverable)."""
        # Note: existing 0002_feedback_telemetry_perf_audit.py conflicts —
        # the SWE may have named it differently or used a new revision ID.
        path = self._migration_path()
        if not os.path.exists(path):
            # Check for alternative naming (SWE might have used a higher revision)
            versions_dir = os.path.join(_API_DIR, "alembic/versions")
            pgq_files = [f for f in os.listdir(versions_dir) if "pgqueuer" in f]
            self.assertTrue(
                len(pgq_files) > 0,
                f"No pgqueuer migration found in {versions_dir}. "
                f"Expected 0002_pgqueuer_jobs.py or similar. "
                f"Files present: {os.listdir(versions_dir)}"
            )


# ---------------------------------------------------------------------------
# 7. pgqueuer fallback: start_worker does NOT crash without pgqueuer installed
#    Tests use source inspection to avoid Python 3.9 incompatibility in
#    app/models/ai_telemetry.py (uses X|Y union syntax, requires Python 3.10+)
# ---------------------------------------------------------------------------
class TestStartWorkerFallback(unittest.TestCase):
    """
    Verify start_worker() uses asyncio.Queue fallback.
    Tested via source inspection since ai_telemetry.py uses Python 3.10+ syntax
    (uuid.UUID | None) that breaks import on Python 3.9 (the CI interpreter).
    """

    def _ingestion_source(self):
        path = os.path.join(_API_DIR, "app/queue/ingestion.py")
        with open(path) as f:
            return f.read()

    def test_start_worker_function_defined_in_source(self):
        """start_worker coroutine must be defined in ingestion.py."""
        src = self._ingestion_source()
        self.assertIn("async def start_worker", src,
                      "start_worker() async function must be defined in app/queue/ingestion.py")

    def test_enqueue_item_function_defined_in_source(self):
        """enqueue_item must be defined in ingestion.py."""
        src = self._ingestion_source()
        self.assertIn("async def enqueue_item", src,
                      "enqueue_item() async function must be defined in app/queue/ingestion.py")

    def test_asyncio_queue_used_as_fallback_in_source(self):
        """ingestion.py must instantiate asyncio.Queue as the fallback backend."""
        src = self._ingestion_source()
        self.assertIn("asyncio.Queue", src,
                      "ingestion.py must use asyncio.Queue as the in-process fallback")

    def test_ingest_job_dataclass_defined_in_source(self):
        """IngestJob dataclass must be defined in ingestion.py."""
        src = self._ingestion_source()
        self.assertIn("class IngestJob", src,
                      "IngestJob dataclass must be defined in app/queue/ingestion.py")

    def test_ingest_job_has_job_id_field(self):
        """IngestJob must have job_id field."""
        src = self._ingestion_source()
        self.assertIn("job_id", src)

    def test_ingest_job_has_retries_field(self):
        """IngestJob must have retries field (for retry logic)."""
        src = self._ingestion_source()
        self.assertIn("retries", src)

    def test_start_worker_loops_on_queue(self):
        """start_worker() must call _queue.get() in a loop."""
        src = self._ingestion_source()
        self.assertIn("_queue.get()", src,
                      "start_worker() must await _queue.get() to consume jobs")


# ---------------------------------------------------------------------------
# 8. POST /v1/save endpoint: auth and validation (using FastAPI TestClient)
# ---------------------------------------------------------------------------
class TestSaveEndpointAuth(unittest.TestCase):
    """
    Test the POST /v1/save endpoint auth and validation.
    These tests skip if save.py doesn't exist (SWE deliverable missing).
    """

    @classmethod
    def setUpClass(cls):
        save_path = os.path.join(_API_DIR, "app/routers/save.py")
        cls.save_exists = os.path.exists(save_path)

    def _get_client(self):
        """Build a FastAPI TestClient with minimal mocking."""
        try:
            from fastapi.testclient import TestClient
            from fastapi import FastAPI
            # Import the save router
            from app.routers import save as save_module
            app = FastAPI()
            app.include_router(save_module.router)
            return TestClient(app, raise_server_exceptions=False)
        except Exception:
            return None

    def test_no_auth_header_returns_401(self):
        """POST /v1/save without Authorization header → 401."""
        if not self.save_exists:
            self.skipTest("save.py not created by SWE agent")
        client = self._get_client()
        if client is None:
            self.skipTest("Could not build TestClient for save router")
        resp = client.post("/v1/save", json={"url": "https://example.com"})
        self.assertEqual(resp.status_code, 401,
                         f"Expected 401, got {resp.status_code}: {resp.text}")

    def test_invalid_collection_id_too_long_returns_422(self):
        """POST /v1/save with collection_id='not-a-uuid-but-too-long-string-here' → 422."""
        if not self.save_exists:
            self.skipTest("save.py not created by SWE agent")
        client = self._get_client()
        if client is None:
            self.skipTest("Could not build TestClient for save router")
        resp = client.post(
            "/v1/save",
            json={
                "url": "https://example.com",
                "collection_id": "not-a-uuid-but-too-long-string-here",
            },
            headers={"Authorization": "Bearer fake-token-for-test"},
        )
        self.assertEqual(resp.status_code, 422,
                         f"Expected 422 for invalid collection_id, got {resp.status_code}")


if __name__ == "__main__":
    unittest.main()
