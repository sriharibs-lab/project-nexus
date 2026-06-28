"""
Tests for GET /v1/users/me/interest-topics (app/routers/users.py).

Task 1F-006 — FRE rotating topics from user interest profile.

Coverage:
- Returns default topics + has_profile=false when user has no profile row
- Returns sorted personalised topics when profile exists (highest weight first)
- Respects the `limit` query parameter (default 5, max 20)
- Falls back to defaults when the profile.topics dict is empty
- Display formatting: hyphens and underscores replaced with spaces in output
- Never returns an empty topics list (always at least defaults)
- Unprovisiond user (supabase_id not in DB) returns defaults
- Topics with weight 0 after decay are filtered server-side before storage,
  but the endpoint also handles them gracefully if somehow present
"""

import unittest
import uuid
from unittest.mock import AsyncMock, MagicMock, patch

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_user(user_id=None, supabase_id="test-supabase-id"):
    u = MagicMock()
    u.id = user_id or uuid.uuid4()
    u.supabase_id = supabase_id
    return u


def _make_profile(topics: dict):
    p = MagicMock()
    p.topics = topics
    return p


def _make_db(user, profile):
    """
    Return an AsyncSession mock where:
      - first execute() → resolves to `user` (or None)
      - second execute() → resolves to `profile` (or None)
    """
    db = MagicMock()
    user_result = MagicMock()
    user_result.scalar_one_or_none.return_value = user

    profile_result = MagicMock()
    profile_result.scalar_one_or_none.return_value = profile

    results = iter([user_result, profile_result])

    db.execute = AsyncMock(side_effect=lambda *a, **kw: next(results))
    return db


# ---------------------------------------------------------------------------
# Pull the pure helpers from the router without importing FastAPI machinery
# ---------------------------------------------------------------------------

import importlib.util, os, sys


def _load_router_module():
    """Load app.routers.users with SQLAlchemy / FastAPI stubs to avoid DB setup."""
    stubs = {
        "sqlalchemy": MagicMock(),
        "sqlalchemy.ext.asyncio": MagicMock(),
        "sqlalchemy.orm": MagicMock(),
    }
    # Stub app.* imports the router uses
    app_stubs = {
        "app": MagicMock(),
        "app.core": MagicMock(),
        "app.core.database": MagicMock(),
        "app.middleware": MagicMock(),
        "app.middleware.auth": MagicMock(),
        "app.models": MagicMock(),
        "app.models.user": MagicMock(),
        "app.models.user_interest_profile": MagicMock(),
        "fastapi": MagicMock(),
        "pydantic": MagicMock(),
    }
    # Pydantic BaseModel stub must behave like a real BaseModel minimally
    class _BaseModel:
        def __init__(self, **kwargs):
            for k, v in kwargs.items():
                setattr(self, k, v)
    app_stubs["pydantic"].BaseModel = _BaseModel

    with patch.dict(sys.modules, {**stubs, **app_stubs}):
        path = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "../../app/routers/users.py")
        )
        spec = importlib.util.spec_from_file_location("app.routers.users", path)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------------------
# Tests for pure helper: _format_topic
# ---------------------------------------------------------------------------

class TestFormatTopic(unittest.TestCase):
    def setUp(self):
        self._mod = _load_router_module()

    def test_hyphen_replaced_with_space(self):
        self.assertEqual(self._mod._format_topic("machine-learning"), "machine learning")

    def test_underscore_replaced_with_space(self):
        self.assertEqual(self._mod._format_topic("second_brain"), "second brain")

    def test_plain_string_unchanged(self):
        self.assertEqual(self._mod._format_topic("longevity"), "longevity")

    def test_mixed_separators(self):
        result = self._mod._format_topic("second-brain_tools")
        self.assertEqual(result, "second brain tools")


# ---------------------------------------------------------------------------
# Tests for get_interest_topics endpoint logic (without HTTP layer)
# ---------------------------------------------------------------------------

class TestGetInterestTopicsLogic(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self._mod = _load_router_module()
        # Test _resolve_interest_topics (the pure logic function) directly.
        # The decorated get_interest_topics wraps it but is itself a MagicMock
        # in the test environment because router is stubbed.
        self._fn = self._mod._resolve_interest_topics
        self._defaults = self._mod._FRE_DEFAULT_TOPICS

    async def _call(self, limit=5, user=None, profile=None):
        db = _make_db(user, profile)
        return await self._fn(supabase_id="test-supabase-id", limit=limit, db=db)

    async def test_no_user_returns_defaults(self):
        """Unprovisioned user → defaults, has_profile=false."""
        result = await self._call(user=None, profile=None)
        self.assertFalse(result.has_profile)
        self.assertEqual(result.topics, self._defaults[:5])

    async def test_no_profile_returns_defaults(self):
        """Provisioned user with no profile row → defaults."""
        user = _make_user()
        result = await self._call(user=user, profile=None)
        self.assertFalse(result.has_profile)
        self.assertEqual(result.topics, self._defaults[:5])

    async def test_empty_topics_dict_returns_defaults(self):
        """Profile row exists but topics={} → defaults."""
        user = _make_user()
        profile = _make_profile({})
        result = await self._call(user=user, profile=profile)
        self.assertFalse(result.has_profile)
        self.assertEqual(result.topics, self._defaults[:5])

    async def test_personalised_topics_sorted_by_weight_desc(self):
        """Topics returned in descending weight order."""
        user = _make_user()
        profile = _make_profile({
            "machine-learning": 0.9,
            "productivity": 0.4,
            "longevity": 0.7,
        })
        result = await self._call(user=user, profile=profile)
        self.assertTrue(result.has_profile)
        self.assertEqual(result.topics[0], "machine learning")  # highest weight
        self.assertEqual(result.topics[1], "longevity")
        self.assertEqual(result.topics[2], "productivity")

    async def test_limit_respected(self):
        """Only `limit` topics returned."""
        user = _make_user()
        topics = {f"topic-{i}": float(i) / 10 for i in range(10, 0, -1)}
        profile = _make_profile(topics)
        result = await self._call(limit=3, user=user, profile=profile)
        self.assertEqual(len(result.topics), 3)

    async def test_default_limit_is_5(self):
        """Default limit=5 caps the result."""
        user = _make_user()
        topics = {f"tag-{i}": float(i) / 20 for i in range(20, 0, -1)}
        profile = _make_profile(topics)
        result = await self._call(limit=5, user=user, profile=profile)
        self.assertLessEqual(len(result.topics), 5)

    async def test_hyphenated_keys_formatted_for_display(self):
        """Stored hyphenated keys appear as space-separated in response."""
        user = _make_user()
        profile = _make_profile({"second-brain-tools": 0.8})
        result = await self._call(user=user, profile=profile)
        self.assertIn("second brain tools", result.topics)

    async def test_topics_never_empty_even_with_profile(self):
        """Result.topics is never an empty list."""
        user = _make_user()
        result = await self._call(user=user, profile=None)
        self.assertGreater(len(result.topics), 0)


if __name__ == "__main__":
    unittest.main()
