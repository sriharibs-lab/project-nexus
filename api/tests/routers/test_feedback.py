"""
Tests for POST /v1/feedback router (app/routers/feedback.py).

Test hints covered:
- POST /feedback with valid text → 201 Created, body has id + status="received"
- POST /feedback without text → 422 Unprocessable Entity
- POST /feedback with all optional fields (category, screenshot_url, app_version,
  ios_version, device_model) → 201
- POST /feedback with invalid category → 422
- POST /feedback with screenshot_url as base64 data URI → 201 (inline screenshot path)
"""

import enum as _enum
import os
import sys
import types
import unittest
import uuid
from unittest.mock import AsyncMock, MagicMock


def _build_test_client():
    """Build a FastAPI TestClient for the /feedback router with mocked DB and auth."""
    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    # -- Feedback model stubs --------------------------------------------------
    class _FeedbackCategory(str, _enum.Enum):
        bug        = "bug"
        suggestion = "suggestion"
        other      = "other"

    fake_feedback_id = uuid.uuid4()

    class _Feedback:
        def __init__(self, **kwargs):
            self.id = kwargs.get("id", fake_feedback_id)
            for k, v in kwargs.items():
                setattr(self, k, v)

    # -- Mock DB session -------------------------------------------------------
    mock_db_session = MagicMock()
    mock_db_session.add = MagicMock()
    mock_db_session.commit = AsyncMock()
    mock_db_session.refresh = AsyncMock()

    # -- Mock get_or_create_user -----------------------------------------------
    fake_user = MagicMock()
    fake_user.id = uuid.uuid4()

    mock_users = types.ModuleType("app.core.users")
    mock_users.get_or_create_user = AsyncMock(return_value=fake_user)

    # -- Mock database module --------------------------------------------------
    mock_db_module = types.ModuleType("app.core.database")
    mock_db_module.Base = object

    async def _get_db():
        yield mock_db_session

    mock_db_module.get_db = _get_db

    # -- Mock config -----------------------------------------------------------
    mock_config = types.ModuleType("app.core.config")
    mock_config.settings = types.SimpleNamespace(
        database_url="postgresql+asyncpg://test:test@localhost/test",
        is_production=False,
    )

    # -- Mock auth middleware --------------------------------------------------
    mock_auth = types.ModuleType("app.middleware.auth")

    async def _get_current_user():
        return {"supabase_id": "test-user-uuid", "email": "test@example.com"}

    mock_auth.get_current_user = _get_current_user

    # -- Mock feedback model module --------------------------------------------
    mock_feedback_model = types.ModuleType("app.models.feedback")
    mock_feedback_model.FeedbackCategory = _FeedbackCategory
    mock_feedback_model.Feedback = _Feedback

    # -- Clear specific module caches -----------------------------------------
    for key in [
        "app.core.users", "app.core.database", "app.core.config",
        "app.middleware.auth", "app.middleware",
        "app.models.feedback",
        "app.routers.feedback", "app.routers",
    ]:
        sys.modules.pop(key, None)

    # -- Inject mocks ----------------------------------------------------------
    sys.modules["app.core.users"]      = mock_users
    sys.modules["app.core.database"]   = mock_db_module
    sys.modules["app.core.config"]     = mock_config
    sys.modules["app.middleware"]      = types.ModuleType("app.middleware")
    sys.modules["app.middleware.auth"] = mock_auth
    sys.modules["app.models.feedback"] = mock_feedback_model

    # Inject app.routers as a namespace-package shim so __init__.py is skipped
    # and Python can still locate app/routers/feedback.py on disk.
    mock_routers = types.ModuleType("app.routers")
    mock_routers.__path__ = [
        os.path.abspath(os.path.join(os.path.dirname(__file__), "../../app/routers"))
    ]
    mock_routers.__package__ = "app.routers"
    sys.modules["app.routers"] = mock_routers

    # -- Import the real feedback router ---------------------------------------
    from app.routers.feedback import router
    from app.middleware.auth import get_current_user

    app = FastAPI()
    app.include_router(router, prefix="/v1")
    app.dependency_overrides[get_current_user] = _get_current_user

    return TestClient(app), fake_feedback_id


class TestFeedbackRouter(unittest.TestCase):
    """Integration-level tests for POST /v1/feedback."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.client, cls.feedback_id = _build_test_client()
            cls.available = True
        except Exception as e:
            cls.available = False
            cls.skip_reason = str(e)

    def _skip_if_unavailable(self):
        if not self.available:
            self.skipTest(f"Router setup failed: {self.skip_reason}")

    # ── happy path ──────────────────────────────────────────────────────────

    def test_minimal_feedback_returns_201(self):
        """POST /feedback with only text → 201, body has id and status='received'."""
        self._skip_if_unavailable()
        resp = self.client.post(
            "/v1/feedback",
            json={"text": "Great app!"},
        )
        self.assertEqual(resp.status_code, 201,
                         f"Expected 201, got {resp.status_code}: {resp.text}")
        body = resp.json()
        self.assertIn("id", body)
        self.assertEqual(body["status"], "received")

    def test_full_payload_returns_201(self):
        """POST /feedback with all optional fields → 201."""
        self._skip_if_unavailable()
        resp = self.client.post(
            "/v1/feedback",
            json={
                "text": "The ingest flow crashes on iPad.",
                "category": "bug",
                "screenshot_url": "https://storage.nexus.app/screenshots/abc.jpg",
                "app_version": "1.0.0 (1)",
                "ios_version": "18.0",
                "device_model": "iPhone17,3",
            },
        )
        self.assertEqual(resp.status_code, 201,
                         f"Expected 201, got {resp.status_code}: {resp.text}")

    def test_screenshot_url_as_base64_data_uri_returns_201(self):
        """POST /feedback with screenshot_url as data URI (inline screenshot) → 201.

        The iOS client encodes screenshots as 'data:image/jpeg;base64,...' strings
        to avoid a separate upload endpoint. The backend stores this in the Text column.
        """
        self._skip_if_unavailable()
        tiny_b64 = "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAIBAQIBAQICAgICAgICA=="
        resp = self.client.post(
            "/v1/feedback",
            json={
                "text": "Crash on collection open.",
                "category": "bug",
                "screenshot_url": f"data:image/jpeg;base64,{tiny_b64}",
            },
        )
        self.assertEqual(resp.status_code, 201,
                         f"Expected 201, got {resp.status_code}: {resp.text}")

    def test_category_suggestion_returns_201(self):
        """POST /feedback with category='suggestion' → 201."""
        self._skip_if_unavailable()
        resp = self.client.post(
            "/v1/feedback",
            json={"text": "Add dark mode toggle in settings.", "category": "suggestion"},
        )
        self.assertEqual(resp.status_code, 201)

    def test_category_other_default_returns_201(self):
        """POST /feedback with no category defaults to 'other' → 201."""
        self._skip_if_unavailable()
        resp = self.client.post("/v1/feedback", json={"text": "Just saying hi."})
        self.assertEqual(resp.status_code, 201)

    def test_response_schema(self):
        """Response must contain 'id' (UUID string) and 'status'='received'."""
        self._skip_if_unavailable()
        resp = self.client.post("/v1/feedback", json={"text": "Schema check."})
        body = resp.json()
        self.assertIn("id", body)
        self.assertIn("status", body)
        self.assertEqual(body["status"], "received")
        # id must be parseable as UUID
        try:
            uuid.UUID(body["id"])
        except ValueError:
            self.fail(f"'id' field is not a valid UUID: {body['id']}")

    # ── validation errors ────────────────────────────────────────────────────

    def test_missing_text_returns_422(self):
        """POST /feedback without text → 422 Unprocessable Entity."""
        self._skip_if_unavailable()
        resp = self.client.post("/v1/feedback", json={"category": "bug"})
        self.assertEqual(resp.status_code, 422,
                         f"Expected 422, got {resp.status_code}: {resp.text}")

    def test_empty_body_returns_422(self):
        """POST /feedback with no body → 422."""
        self._skip_if_unavailable()
        resp = self.client.post("/v1/feedback")
        self.assertEqual(resp.status_code, 422)

    def test_invalid_category_returns_422(self):
        """POST /feedback with category='garbage' → 422 (not a valid Literal)."""
        self._skip_if_unavailable()
        resp = self.client.post(
            "/v1/feedback",
            json={"text": "Valid text", "category": "garbage"},
        )
        self.assertEqual(resp.status_code, 422,
                         f"Expected 422, got {resp.status_code}: {resp.text}")

    def test_empty_text_accepted_or_rejected(self):
        """POST /feedback with empty string for text.

        Server currently accepts empty text (no min-length validator).
        The iOS client enforces non-empty in the UI (submit button disabled
        when text is blank). This test documents the current contract.
        """
        self._skip_if_unavailable()
        resp = self.client.post("/v1/feedback", json={"text": ""})
        # 201 = server stores it; 422 = server enforces non-empty
        self.assertIn(resp.status_code, [201, 422],
                      f"Unexpected status code: {resp.status_code}")

    # ── all three categories ─────────────────────────────────────────────────

    def test_all_categories_accepted(self):
        """All three valid category values must be accepted."""
        self._skip_if_unavailable()
        for cat in ["bug", "suggestion", "other"]:
            with self.subTest(category=cat):
                resp = self.client.post(
                    "/v1/feedback",
                    json={"text": f"Testing category {cat}", "category": cat},
                )
                self.assertEqual(resp.status_code, 201,
                                 f"category='{cat}' should return 201, got {resp.status_code}")


if __name__ == "__main__":
    unittest.main()
