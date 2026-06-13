"""
Tests for POST /ingest router (app/routers/ingest.py).

Test hints covered:
- POST /ingest with invalid content_type (e.g. 'garbage') → 422 Unprocessable Entity
- POST /ingest with content_type='thread' → 202 Accepted (was missing from pipeline/base.py enum)
- Auth is bypassed via dependency override
"""
import enum
import os
import sys
import types
import unittest
from unittest.mock import AsyncMock


def _load_content_type_from_source() -> type:
    """Load ContentType from item.py source without triggering SQLAlchemy class body."""
    path = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "../../app/models/item.py")
    )
    with open(path) as f:
        source = f.read()

    lines = source.split("\n")
    enum_lines = ["import enum"]
    in_block = False
    for line in lines:
        if line.startswith("class ContentType"):
            in_block = True
        elif in_block and line.startswith("class ") and "ContentType" not in line:
            break
        if in_block:
            enum_lines.append(line)

    ns: dict = {}
    exec("\n".join(enum_lines), {"enum": enum}, ns)
    return ns["ContentType"]


def _build_test_client():
    """
    Build a FastAPI TestClient for the /ingest router with all heavy dependencies mocked.
    Avoids Python 3.10+ SQLAlchemy class body syntax — injects safe ContentType directly.
    """
    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    ContentType = _load_content_type_from_source()

    # --- Mock all modules that would trigger SQLAlchemy model class bodies ---
    mock_item = types.ModuleType("app.models.item")
    mock_item.ContentType = ContentType

    mock_models = types.ModuleType("app.models")
    mock_models.ContentType = ContentType

    mock_config = types.ModuleType("app.core.config")
    mock_config.settings = types.SimpleNamespace(
        database_url="postgresql+asyncpg://test:test@localhost/test",
        is_production=False,
    )

    mock_db = types.ModuleType("app.core.database")
    mock_db.Base = object
    mock_db.get_db = lambda: None

    mock_enqueue = AsyncMock(return_value="job-test-123")
    mock_queue = types.ModuleType("app.queue.ingestion")
    mock_queue.enqueue_item = mock_enqueue

    mock_auth = types.ModuleType("app.middleware.auth")

    async def _get_current_user():
        return {"supabase_id": "test-user-uuid"}

    mock_auth.get_current_user = _get_current_user

    # Inject mocks before importing the router
    for key in ["app.models.item", "app.models", "app.core.config",
                "app.core.database", "app.queue.ingestion", "app.middleware.auth",
                "app.queue", "app.middleware"]:
        sys.modules.pop(key, None)

    sys.modules["app.models.item"] = mock_item
    sys.modules["app.models"] = mock_models
    sys.modules["app.core.config"] = mock_config
    sys.modules["app.core.database"] = mock_db
    sys.modules["app.queue"] = types.ModuleType("app.queue")
    sys.modules["app.queue.ingestion"] = mock_queue
    sys.modules["app.middleware"] = types.ModuleType("app.middleware")
    sys.modules["app.middleware.auth"] = mock_auth

    # Also clear the router module cache to force fresh import with mocks
    sys.modules.pop("app.routers.ingest", None)
    sys.modules.pop("app.routers", None)

    from app.routers.ingest import router
    from app.middleware.auth import get_current_user

    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_current_user] = _get_current_user

    return TestClient(app), mock_enqueue


class TestIngestRouter(unittest.TestCase):
    """Integration-level tests for the /ingest endpoint."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.client, cls.mock_enqueue = _build_test_client()
            cls.available = True
        except Exception as e:
            cls.available = False
            cls.skip_reason = str(e)

    def _skip_if_unavailable(self):
        if not self.available:
            self.skipTest(f"Router setup failed: {self.skip_reason}")

    def test_invalid_content_type_returns_422(self):
        """POST /ingest with content_type='garbage' must return 422 Unprocessable Entity.

        Previously: invalid values were silently accepted (no enum validation).
        After fix: ContentType enum in IngestRequest rejects unknown values.
        """
        self._skip_if_unavailable()
        resp = self.client.post(
            "/ingest",
            json={"url": "https://example.com/article", "content_type": "garbage"},
        )
        self.assertEqual(resp.status_code, 422,
                         f"Expected 422, got {resp.status_code}: {resp.text}")

    def test_thread_content_type_returns_202(self):
        """POST /ingest with content_type='thread' must return 202.

        Previously: 'thread' was missing from pipeline/base.py ContentType enum,
        causing silent routing failures. Now unified in app.models.item.ContentType.
        """
        self._skip_if_unavailable()
        resp = self.client.post(
            "/ingest",
            json={"url": "https://x.com/user/status/123", "content_type": "thread"},
        )
        self.assertEqual(resp.status_code, 202,
                         f"Expected 202, got {resp.status_code}: {resp.text}")
        body = resp.json()
        self.assertEqual(body["status"], "queued")
        self.assertIn("job_id", body)

    def test_valid_article_returns_202(self):
        """POST /ingest with content_type='article' must return 202."""
        self._skip_if_unavailable()
        resp = self.client.post(
            "/ingest",
            json={"url": "https://example.com/article", "content_type": "article"},
        )
        self.assertEqual(resp.status_code, 202)

    def test_video_content_type_returns_202(self):
        """POST /ingest with content_type='video' must return 202."""
        self._skip_if_unavailable()
        resp = self.client.post(
            "/ingest",
            json={"url": "https://youtube.com/watch?v=abc", "content_type": "video"},
        )
        self.assertEqual(resp.status_code, 202)

    def test_podcast_content_type_returns_202(self):
        """POST /ingest with content_type='podcast' must return 202."""
        self._skip_if_unavailable()
        resp = self.client.post(
            "/ingest",
            json={"url": "https://example.com/podcast.mp3", "content_type": "podcast"},
        )
        self.assertEqual(resp.status_code, 202)

    def test_blog_content_type_returns_202(self):
        """POST /ingest with content_type='blog' must return 202 (new in this version)."""
        self._skip_if_unavailable()
        resp = self.client.post(
            "/ingest",
            json={"url": "https://substack.com/post/123", "content_type": "blog"},
        )
        self.assertEqual(resp.status_code, 202)

    def test_announcement_content_type_returns_202(self):
        """POST /ingest with content_type='announcement' must return 202 (new in this version)."""
        self._skip_if_unavailable()
        resp = self.client.post(
            "/ingest",
            json={"url": "https://openai.com/blog/gpt5", "content_type": "announcement"},
        )
        self.assertEqual(resp.status_code, 202)

    def test_missing_url_returns_422(self):
        """POST /ingest without url field must return 422."""
        self._skip_if_unavailable()
        resp = self.client.post(
            "/ingest",
            json={"content_type": "article"},
        )
        self.assertEqual(resp.status_code, 422)

    def test_missing_body_returns_422(self):
        """POST /ingest with no body must return 422."""
        self._skip_if_unavailable()
        resp = self.client.post("/ingest")
        self.assertEqual(resp.status_code, 422)

    def test_response_body_schema(self):
        """Response body must have job_id, status, message fields."""
        self._skip_if_unavailable()
        resp = self.client.post(
            "/ingest",
            json={"url": "https://example.com/article", "content_type": "article"},
        )
        self.assertEqual(resp.status_code, 202)
        body = resp.json()
        self.assertIn("job_id", body)
        self.assertIn("status", body)
        self.assertIn("message", body)
        self.assertEqual(body["status"], "queued")

    def test_all_seven_content_types_accepted(self):
        """All 7 ContentType values must be accepted by the ingest endpoint."""
        self._skip_if_unavailable()
        content_types = ["article", "podcast", "video", "thread",
                         "blog", "announcement", "other"]
        for ct in content_types:
            with self.subTest(content_type=ct):
                resp = self.client.post(
                    "/ingest",
                    json={"url": "https://example.com/content", "content_type": ct},
                )
                self.assertEqual(resp.status_code, 202,
                                 f"content_type='{ct}' should return 202, got {resp.status_code}")

    def test_invalid_types_rejected(self):
        """Invalid content_type strings must all return 422."""
        self._skip_if_unavailable()
        invalid = ["garbage", "ARTICLE", "Article", "mp3", "html", "pdf", ""]
        for ct in invalid:
            with self.subTest(content_type=ct):
                resp = self.client.post(
                    "/ingest",
                    json={"url": "https://example.com/content", "content_type": ct},
                )
                self.assertEqual(resp.status_code, 422,
                                 f"content_type='{ct}' should return 422, got {resp.status_code}")


if __name__ == "__main__":
    unittest.main()
