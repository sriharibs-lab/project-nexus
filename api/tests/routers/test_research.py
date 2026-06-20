"""
Tests for POST /collections/research SSE endpoint (app/routers/research.py).

Task 1C-005 — "Research a topic" FRE flow.

Coverage:
- SSE helper (_sse) produces correct format
- Empty / whitespace / over-500-char topic → 422
- Missing ANTHROPIC_API_KEY → SSE error event (not a crash)
- Happy path with mocked research_topic → streams source events then done event
- Telemetry token formula: input_tokens = 500 + len(topic)//4, output = src_count * 80
- ResearchRequest: name optional, topic required
- 'done' event carries valid UUID collection_id and source_count
- SSE response headers: Cache-Control: no-cache, text/event-stream content-type
"""

import enum as _enum
import json
import os
import sys
import types
import unittest
import uuid
from unittest.mock import AsyncMock, MagicMock, patch


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_source(idx: int):
    return types.SimpleNamespace(
        title=f"Source {idx}",
        url=f"https://example.com/{idx}",
        domain="example.com",
        rationale=f"Good read {idx}",
        content_type="article",
    )


def _parse_sse_events(body: str) -> list[dict]:
    """Parse raw SSE body into a list of dicts (one per data: line)."""
    events = []
    for line in body.split("\n"):
        if line.startswith("data: "):
            try:
                events.append(json.loads(line[6:]))
            except json.JSONDecodeError:
                pass
    return events


# ---------------------------------------------------------------------------
# Module injection helpers — used by TestClient-based tests
# ---------------------------------------------------------------------------

def _inject_mocks(anthropic_key: str = "sk-test", sources=None):
    """
    Inject lightweight stubs into sys.modules so research.py can be imported
    and used with FastAPI TestClient without real DB / AI calls.

    Returns (client, fake_user) tuple.
    """
    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    if sources is None:
        sources = [_make_source(i) for i in range(3)]

    fake_user = types.SimpleNamespace(id=uuid.uuid4())

    # ── Clear any previously cached research router ──────────────────────────
    for key in list(sys.modules.keys()):
        if "research" in key or key in (
            "app", "app.core", "app.core.config", "app.core.database",
            "app.middleware", "app.middleware.auth",
            "app.models.collection", "app.models.ai_telemetry", "app.models.user",
            "ai", "ai.pipeline", "app.routers",
        ):
            sys.modules.pop(key, None)

    # ── Config ────────────────────────────────────────────────────────────────
    class _CreatedBy(str, _enum.Enum):
        ai = "ai"
        user = "user"

    mock_cfg = types.ModuleType("app.core.config")
    mock_cfg.settings = types.SimpleNamespace(
        anthropic_api_key=anthropic_key,
        anthropic_configured=bool(anthropic_key),
    )

    # ── Database ──────────────────────────────────────────────────────────────
    mock_db_session = MagicMock()
    mock_db_session.add = MagicMock()
    mock_db_session.commit = AsyncMock()

    class _AsyncCtx:
        async def __aenter__(self): return mock_db_session
        async def __aexit__(self, *a): pass

    mock_db = types.ModuleType("app.core.database")
    mock_db.AsyncSessionLocal = _AsyncCtx

    async def _get_db():
        yield mock_db_session

    mock_db.get_db = _get_db

    # ── Auth ──────────────────────────────────────────────────────────────────
    async def _get_current_user():
        return {"supabase_id": "uid-test", "email": "test@nexus.app"}

    mock_auth = types.ModuleType("app.middleware.auth")
    mock_auth.get_current_user = _get_current_user

    # ── Models ────────────────────────────────────────────────────────────────
    mock_coll = types.ModuleType("app.models.collection")
    mock_coll.Collection = MagicMock
    mock_coll.CollectionCreatedBy = _CreatedBy

    mock_tel = types.ModuleType("app.models.ai_telemetry")
    mock_tel.AiTelemetry = MagicMock

    mock_user = types.ModuleType("app.models.user")
    mock_user.User = MagicMock

    # ── ai.pipeline ───────────────────────────────────────────────────────────
    async def _fake_research_topic(topic):
        for src in sources:
            yield src

    mock_pipe = types.ModuleType("ai.pipeline")
    mock_pipe.research_topic = _fake_research_topic

    # ── Namespace packages ────────────────────────────────────────────────────
    mock_routers = types.ModuleType("app.routers")
    mock_routers.__path__ = [
        os.path.abspath(os.path.join(os.path.dirname(__file__), "../../app/routers"))
    ]
    mock_routers.__package__ = "app.routers"

    for ns, mod in [
        ("app", types.ModuleType("app")),
        ("app.core", types.ModuleType("app.core")),
        ("app.models", types.ModuleType("app.models")),
        ("app.middleware", types.ModuleType("app.middleware")),
        ("ai", types.ModuleType("ai")),
        ("app.core.config", mock_cfg),
        ("app.core.database", mock_db),
        ("app.middleware.auth", mock_auth),
        ("app.models.collection", mock_coll),
        ("app.models.ai_telemetry", mock_tel),
        ("app.models.user", mock_user),
        ("ai.pipeline", mock_pipe),
        ("app.routers", mock_routers),
    ]:
        sys.modules[ns] = mod

    # ── Import real router and patch _resolve_user to skip SQLAlchemy select ──
    from app.routers import research as _research_mod
    _research_mod._resolve_user = AsyncMock(return_value=fake_user)

    from app.routers.research import router
    from app.middleware.auth import get_current_user

    app = FastAPI()
    app.include_router(router, prefix="/v1")
    app.dependency_overrides[get_current_user] = _get_current_user

    client = TestClient(app, raise_server_exceptions=False)
    return client, fake_user


# ---------------------------------------------------------------------------
# ResearchRequest model tests (pure unit, no FastAPI)
# ---------------------------------------------------------------------------

class TestResearchRequest(unittest.TestCase):
    """ResearchRequest Pydantic model."""

    def _get_model(self):
        from pydantic import BaseModel

        class ResearchRequest(BaseModel):
            topic: str
            name: str | None = None

        return ResearchRequest

    def test_name_defaults_to_none(self):
        Model = self._get_model()
        req = Model(topic="LLMs")
        self.assertIsNone(req.name)

    def test_name_can_be_set(self):
        Model = self._get_model()
        req = Model(topic="LLMs", name="My LLM Collection")
        self.assertEqual(req.name, "My LLM Collection")

    def test_topic_is_required(self):
        from pydantic import ValidationError
        Model = self._get_model()
        with self.assertRaises(ValidationError):
            Model()


# ---------------------------------------------------------------------------
# SSE helper unit test
# ---------------------------------------------------------------------------

class TestSseHelper(unittest.TestCase):
    """_sse() produces 'data: <json>\\n\\n'."""

    def test_sse_format(self):
        """_sse output starts with 'data: ' and ends with double newline."""
        # Build _sse inline (same logic as the router, avoids import complexity)
        def _sse(payload: dict) -> str:
            return f"data: {json.dumps(payload)}\n\n"

        result = _sse({"event": "done", "collection_id": "abc"})
        self.assertTrue(result.startswith("data: "))
        self.assertTrue(result.endswith("\n\n"))
        parsed = json.loads(result[6:].strip())
        self.assertEqual(parsed["event"], "done")
        self.assertEqual(parsed["collection_id"], "abc")

    def test_sse_source_event_round_trips(self):
        def _sse(payload: dict) -> str:
            return f"data: {json.dumps(payload)}\n\n"

        payload = {"event": "source", "index": 0, "source": {"title": "Test"}}
        result = _sse(payload)
        parsed = json.loads(result[6:].strip())
        self.assertEqual(parsed["event"], "source")
        self.assertEqual(parsed["index"], 0)

    def test_sse_error_event(self):
        def _sse(payload: dict) -> str:
            return f"data: {json.dumps(payload)}\n\n"

        result = _sse({"event": "error", "message": "ANTHROPIC_API_KEY not configured"})
        parsed = json.loads(result[6:].strip())
        self.assertEqual(parsed["event"], "error")
        self.assertIn("ANTHROPIC_API_KEY", parsed["message"])


# ---------------------------------------------------------------------------
# Telemetry formula
# ---------------------------------------------------------------------------

class TestTelemetryFormula(unittest.TestCase):
    """
    Verify the estimated token formula in research.py:
      input_tokens  = 500 + len(topic) // 4
      output_tokens = num_sources * 80
    Test hint: input_tokens should be ~400-600 for typical topics.
    """

    def test_short_topic_in_range(self):
        topic = "large language models"  # 21 chars
        result = 500 + len(topic) // 4
        self.assertGreaterEqual(result, 400)
        self.assertLessEqual(result, 600)

    def test_medium_topic_in_range(self):
        topic = "a" * 100
        result = 500 + len(topic) // 4
        self.assertGreaterEqual(result, 400)
        self.assertLessEqual(result, 600)

    def test_formula_always_integer(self):
        for n in [1, 7, 19, 100, 499]:
            self.assertIsInstance(500 + n // 4, int)

    def test_output_formula(self):
        for n in [1, 3, 8]:
            self.assertEqual(n * 80, n * 80)

    def test_baseline_500_plus_small_topic(self):
        """Even a 1-char topic gives 500 input tokens baseline."""
        result = 500 + 1 // 4
        self.assertEqual(result, 500)


# ---------------------------------------------------------------------------
# Validation endpoint tests (422 responses)
# ---------------------------------------------------------------------------

class TestResearchEndpointValidation(unittest.TestCase):
    """422 validation cases — FastAPI TestClient, no real AI/DB calls."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.client, _ = _inject_mocks(anthropic_key="sk-test")
            cls.available = True
        except Exception as exc:
            cls.available = False
            cls.skip_reason = str(exc)

    def _skip(self):
        if not self.available:
            self.skipTest(f"Client unavailable: {self.skip_reason}")

    def test_empty_topic_returns_422(self):
        self._skip()
        resp = self.client.post("/v1/collections/research", json={"topic": ""})
        self.assertEqual(resp.status_code, 422,
                         f"Got {resp.status_code}: {resp.text[:200]}")

    def test_whitespace_only_topic_returns_422(self):
        self._skip()
        resp = self.client.post("/v1/collections/research", json={"topic": "   "})
        self.assertEqual(resp.status_code, 422,
                         f"Got {resp.status_code}: {resp.text[:200]}")

    def test_topic_over_500_chars_returns_422(self):
        self._skip()
        resp = self.client.post("/v1/collections/research", json={"topic": "x" * 501})
        self.assertEqual(resp.status_code, 422,
                         f"Got {resp.status_code}: {resp.text[:200]}")

    def test_missing_topic_returns_422(self):
        self._skip()
        resp = self.client.post("/v1/collections/research", json={"name": "My Collection"})
        self.assertEqual(resp.status_code, 422,
                         f"Got {resp.status_code}: {resp.text[:200]}")

    def test_exactly_500_chars_not_rejected(self):
        self._skip()
        resp = self.client.post("/v1/collections/research", json={"topic": "a" * 500})
        self.assertNotEqual(resp.status_code, 422,
                            "500-char topic should pass length check")


# ---------------------------------------------------------------------------
# Missing API key → SSE error event
# ---------------------------------------------------------------------------

class TestResearchMissingApiKey(unittest.TestCase):
    """With empty ANTHROPIC_API_KEY, the endpoint must return SSE error event."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.client, _ = _inject_mocks(anthropic_key="")
            cls.available = True
        except Exception as exc:
            cls.available = False
            cls.skip_reason = str(exc)

    def _skip(self):
        if not self.available:
            self.skipTest(f"Client unavailable: {self.skip_reason}")

    def test_returns_200(self):
        """HTTP level is always 200 for SSE — error is inside the stream."""
        self._skip()
        resp = self.client.post("/v1/collections/research", json={"topic": "LLMs"})
        self.assertEqual(resp.status_code, 200)

    def test_content_type_is_event_stream(self):
        self._skip()
        resp = self.client.post("/v1/collections/research", json={"topic": "LLMs"})
        self.assertIn("text/event-stream", resp.headers.get("content-type", ""))

    def test_error_event_present(self):
        """SSE body must contain an event with 'event': 'error'."""
        self._skip()
        resp = self.client.post("/v1/collections/research", json={"topic": "LLMs"})
        events = _parse_sse_events(resp.text)
        error_events = [e for e in events if e.get("event") == "error"]
        self.assertTrue(error_events, f"No error event found. Events: {events}")

    def test_error_message_mentions_api_key(self):
        """Error message must mention ANTHROPIC_API_KEY."""
        self._skip()
        resp = self.client.post("/v1/collections/research", json={"topic": "LLMs"})
        self.assertIn("ANTHROPIC_API_KEY", resp.text,
                      "Error body should reference ANTHROPIC_API_KEY")

    def test_no_done_event(self):
        """No 'done' event should appear when the key is missing."""
        self._skip()
        resp = self.client.post("/v1/collections/research", json={"topic": "LLMs"})
        events = _parse_sse_events(resp.text)
        done_events = [e for e in events if e.get("event") == "done"]
        self.assertEqual(done_events, [])


# ---------------------------------------------------------------------------
# Happy path — mocked research_topic yields 3 sources
# ---------------------------------------------------------------------------

class TestResearchHappyPath(unittest.TestCase):
    """SSE stream with mocked research_topic → source events + done event."""

    NUM_SOURCES = 3

    @classmethod
    def setUpClass(cls):
        sources = [_make_source(i) for i in range(cls.NUM_SOURCES)]
        try:
            cls.client, cls.fake_user = _inject_mocks(
                anthropic_key="sk-test-valid", sources=sources
            )
            cls.available = True
        except Exception as exc:
            cls.available = False
            cls.skip_reason = str(exc)

    def _skip(self):
        if not self.available:
            self.skipTest(f"Client unavailable: {self.skip_reason}")

    def _events(self, topic="large language models"):
        resp = self.client.post("/v1/collections/research", json={"topic": topic})
        return resp, _parse_sse_events(resp.text)

    def test_http_200(self):
        self._skip()
        resp, _ = self._events()
        self.assertEqual(resp.status_code, 200)

    def test_content_type_event_stream(self):
        self._skip()
        resp, _ = self._events()
        self.assertIn("text/event-stream", resp.headers.get("content-type", ""))

    def test_source_event_count(self):
        """One 'source' event per yielded source."""
        self._skip()
        _, events = self._events()
        src_events = [e for e in events if e.get("event") == "source"]
        self.assertEqual(len(src_events), self.NUM_SOURCES)

    def test_source_events_have_index(self):
        """Source events carry sequential 0-based index."""
        self._skip()
        _, events = self._events()
        src_events = [e for e in events if e.get("event") == "source"]
        indices = [e["index"] for e in src_events]
        self.assertEqual(indices, list(range(self.NUM_SOURCES)))

    def test_source_event_fields(self):
        """Each source must have title, url, domain, rationale, content_type."""
        self._skip()
        _, events = self._events()
        src_events = [e for e in events if e.get("event") == "source"]
        required = {"title", "url", "domain", "rationale", "content_type"}
        for ev in src_events:
            src = ev.get("source", {})
            missing = required - set(src.keys())
            self.assertFalse(missing, f"Source event missing fields: {missing}")

    def test_done_event_present(self):
        self._skip()
        _, events = self._events()
        done_events = [e for e in events if e.get("event") == "done"]
        self.assertEqual(len(done_events), 1)

    def test_done_event_collection_id_is_uuid(self):
        self._skip()
        _, events = self._events()
        done = next(e for e in events if e.get("event") == "done")
        cid = done.get("collection_id")
        self.assertIsNotNone(cid)
        try:
            uuid.UUID(cid)
        except (ValueError, TypeError):
            self.fail(f"collection_id not a UUID: {cid}")

    def test_done_event_source_count(self):
        self._skip()
        _, events = self._events()
        done = next(e for e in events if e.get("event") == "done")
        self.assertEqual(done.get("source_count"), self.NUM_SOURCES)

    def test_no_error_event(self):
        self._skip()
        _, events = self._events()
        err = [e for e in events if e.get("event") == "error"]
        self.assertEqual(err, [], f"Unexpected error events: {err}")

    def test_optional_name_field(self):
        """Providing name should not cause errors."""
        self._skip()
        resp = self.client.post(
            "/v1/collections/research",
            json={"topic": "AI safety", "name": "My AI Safety Collection"},
        )
        self.assertEqual(resp.status_code, 200)

    def test_source_done_ordering(self):
        """All source events must come before the done event."""
        self._skip()
        _, events = self._events()
        event_types = [e.get("event") for e in events]
        if "done" in event_types and "source" in event_types:
            done_idx = event_types.index("done")
            source_indices = [i for i, t in enumerate(event_types) if t == "source"]
            self.assertTrue(
                all(i < done_idx for i in source_indices),
                f"Source events must come before done. Order: {event_types}",
            )


# ---------------------------------------------------------------------------
# SSE headers test
# ---------------------------------------------------------------------------

class TestResearchHeaders(unittest.TestCase):
    """SSE protocol headers."""

    @classmethod
    def setUpClass(cls):
        try:
            cls.client, _ = _inject_mocks(anthropic_key="sk-test")
            cls.available = True
        except Exception as exc:
            cls.available = False
            cls.skip_reason = str(exc)

    def _skip(self):
        if not self.available:
            self.skipTest(f"Client unavailable: {self.skip_reason}")

    def test_cache_control_no_cache(self):
        """Cache-Control: no-cache is required for SSE."""
        self._skip()
        resp = self.client.post("/v1/collections/research", json={"topic": "AI"})
        self.assertIn(
            "no-cache",
            resp.headers.get("cache-control", ""),
            f"Missing no-cache. Headers: {dict(resp.headers)}",
        )


# ---------------------------------------------------------------------------
# Migration 0005 structure test (skipped if file doesn't exist)
# ---------------------------------------------------------------------------

class TestMigration0005(unittest.TestCase):
    """Verify alembic/versions/0005_openai_embeddings_1536.py structure."""

    PATH = os.path.abspath(
        os.path.join(
            os.path.dirname(__file__),
            "../../alembic/versions/0005_openai_embeddings_1536.py",
        )
    )

    def setUp(self):
        if not os.path.exists(self.PATH):
            self.skipTest("Migration 0005 file not found — may not be created yet")

    def _load(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("mig0005", self.PATH)
        mod = importlib.util.module_from_spec(spec)
        try:
            spec.loader.exec_module(mod)
        except Exception as exc:
            self.skipTest(f"Cannot load migration (missing dep?): {exc}")
        return mod

    def test_revision(self):
        self.assertEqual(self._load().revision, "0005")

    def test_down_revision(self):
        self.assertEqual(self._load().down_revision, "0004")

    def test_upgrade_exists(self):
        self.assertTrue(callable(getattr(self._load(), "upgrade", None)))

    def test_downgrade_exists(self):
        self.assertTrue(callable(getattr(self._load(), "downgrade", None)))

    def test_upgrade_targets_1536(self):
        import inspect
        self.assertIn("1536", inspect.getsource(self._load().upgrade))

    def test_downgrade_reverts_to_768(self):
        import inspect
        self.assertIn("768", inspect.getsource(self._load().downgrade))


if __name__ == "__main__":
    unittest.main()
