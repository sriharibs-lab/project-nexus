"""
Tests for pipeline/jina.py — 1D-005 performance audit.

Coverage:
  - jina.extract() is an async function (not sync — would break asyncio.gather).
  - Timeout is a split Timeout object with distinct connect/read values, not a
    single flat int. This is the key fix: the old code had a single 30s timeout
    that could consume the entire SLO budget before the AI step even started.
  - A simulated timeout produces ExtractionResult.ok == False (not an exception).
  - A successful response sets title, content, word_count correctly.
  - JINA_READ_TIMEOUT env var overrides the read timeout.
"""

import asyncio
import inspect
import os
import sys
import types
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

# ---------------------------------------------------------------------------
# Minimal stubs so pipeline/jina.py can be imported without app.models.*
# ---------------------------------------------------------------------------

def _setup_stubs() -> None:
    """
    pipeline/jina.py imports ContentType from pipeline/base.py (NOT app.models.item).
    pipeline/base.py defines its own ContentType with uppercase members (ARTICLE, VIDEO, etc).
    We do not need to stub app.models.item for jina tests — base.py is self-contained.
    We only ensure the app.* module hierarchy exists so import machinery doesn't error.
    """
    for mod in ["app", "app.models", "app.models.item"]:
        sys.modules.setdefault(mod, types.ModuleType(mod))


_setup_stubs()

# Now we can safely import
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../"))
from pipeline.jina import extract, _get_timeout  # noqa: E402


class TestJinaIsAsync(unittest.TestCase):
    """jina.extract must be an async function (coroutine function)."""

    def test_extract_is_async(self):
        self.assertTrue(
            inspect.iscoroutinefunction(extract),
            "jina.extract must be an async def so it can be awaited "
            "from the event loop without blocking it.",
        )


class TestJinaTimeout(unittest.TestCase):
    """
    Timeout config: split connect / read timeouts, not a single flat int.

    The old code used httpx.get(timeout=30) which could silently consume
    the whole 10s SLO budget waiting for a slow Jina response.
    The fix: connect_timeout=5s (reject slow DNS/TCP), read_timeout=8s.
    """

    def test_timeout_is_httpx_timeout_object(self):
        import httpx
        t = _get_timeout()
        self.assertIsInstance(
            t, httpx.Timeout,
            "_get_timeout() must return an httpx.Timeout (not a raw int).",
        )

    def test_connect_timeout_lte_5s(self):
        t = _get_timeout()
        self.assertLessEqual(
            t.connect, 5.0,
            "connect_timeout must be ≤5s to fail-fast on slow DNS/TCP.",
        )

    def test_read_timeout_lte_8s(self):
        t = _get_timeout()
        self.assertLessEqual(
            t.read, 8.0,
            "read_timeout must be ≤8s so there is budget left for AI + DB.",
        )

    def test_read_timeout_env_override(self):
        """JINA_READ_TIMEOUT env var must override the default."""
        import httpx
        with patch.dict(os.environ, {"JINA_READ_TIMEOUT": "3"}):
            t = _get_timeout()
        self.assertAlmostEqual(
            t.read, 3.0, places=1,
            msg="JINA_READ_TIMEOUT=3 must set read timeout to 3s.",
        )

    def test_connect_timeout_env_override(self):
        """JINA_CONNECT_TIMEOUT env var must override the default."""
        with patch.dict(os.environ, {"JINA_CONNECT_TIMEOUT": "2"}):
            t = _get_timeout()
        self.assertAlmostEqual(
            t.connect, 2.0, places=1,
            msg="JINA_CONNECT_TIMEOUT=2 must set connect timeout to 2s.",
        )


class TestJinaExtractSuccess(unittest.IsolatedAsyncioTestCase):
    """Happy-path: extract() returns a well-formed ExtractionResult."""

    async def test_returns_title_and_content(self):
        fake_body = "Title: Test Article\n\nSome article content here with words."

        mock_response = MagicMock()
        mock_response.text = fake_body
        mock_response.raise_for_status = MagicMock()

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = AsyncMock(return_value=mock_response)

        with patch("pipeline.jina.httpx.AsyncClient", return_value=mock_client):
            result = await extract("https://example.com/article")

        self.assertTrue(result.ok, f"Expected ok, got error={result.error}")
        self.assertEqual(result.title, "Test Article")
        self.assertGreater(result.word_count, 0)
        self.assertIsNone(result.error)
        self.assertGreater(result.elapsed_ms, 0)

    async def test_error_field_set_on_http_error(self):
        import httpx

        mock_response = MagicMock()
        mock_response.raise_for_status = MagicMock(
            side_effect=httpx.HTTPStatusError(
                "404 Not Found",
                request=MagicMock(),
                response=MagicMock(),
            )
        )

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = AsyncMock(return_value=mock_response)

        with patch("pipeline.jina.httpx.AsyncClient", return_value=mock_client):
            result = await extract("https://example.com/missing")

        self.assertFalse(result.ok)
        self.assertIsNotNone(result.error)


class TestJinaExtractTimeout(unittest.IsolatedAsyncioTestCase):
    """Timeout must return ExtractionResult with error, not raise an exception."""

    async def test_timeout_returns_error_result_not_exception(self):
        import httpx

        mock_client = AsyncMock()
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=False)
        mock_client.get = AsyncMock(
            side_effect=httpx.ReadTimeout("Read timed out")
        )

        with patch("pipeline.jina.httpx.AsyncClient", return_value=mock_client):
            # Must not raise — must return an error result
            result = await extract("https://slow-site.example.com/")

        self.assertFalse(result.ok)
        self.assertIn("Timeout", result.error or "")
        self.assertEqual(result.word_count, 0)


if __name__ == "__main__":
    unittest.main()
