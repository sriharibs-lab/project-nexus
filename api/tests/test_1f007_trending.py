"""
Tests for task 1F-007 — Live trending chips backend.

Import strategy: we extract _parse_rss and _get_trending_topics directly from
the routers.trending module by importing via importlib to avoid loading
app/routers/__init__.py (which transitively triggers pydantic-settings
validation for DB credentials not present in the test environment).

Verifies:
  1. _parse_rss correctly extracts up to 4 topic titles from valid Google Trends XML.
  2. _parse_rss raises on malformed XML.
  3. _parse_rss raises ValueError on XML with no <item> titles.
  4. _get_trending_topics returns ("trends", topics) when HTTP fetch succeeds.
  5. _get_trending_topics falls back to ("static", _STATIC_TOPICS) when fetch fails.
  6. Static fallback list has exactly 4 non-empty strings.
  7. In-process cache prevents a second network fetch within TTL.

Run with:
    cd api && pytest tests/test_1f007_trending.py -v
"""

from __future__ import annotations

import importlib
import importlib.util
import sys
import types
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest


# ── Import trending module without triggering app.routers.__init__ ────────────
# We load app.routers.trending directly via importlib so that the eager imports
# in app/routers/__init__.py (collections, ingest, etc.) are never executed and
# pydantic-settings never demands DB credentials.

def _load_trending_module():
    """
    Load api/app/routers/trending.py as a standalone module, bypassing
    app.routers package __init__ to avoid pydantic-settings validation.
    """
    api_root = Path(__file__).parent.parent  # .../api/

    # Create a minimal stub for app.core.config so we can import trending.py
    # without instantiating the real Settings (which requires .env credentials).
    stub_config = types.ModuleType("app.core.config")

    class _StubSettings:
        trending_cache_ttl_seconds: int = 900

    stub_config.settings = _StubSettings()

    # Register stubs before the real module loads
    sys.modules.setdefault("app", types.ModuleType("app"))
    sys.modules.setdefault("app.core", types.ModuleType("app.core"))
    sys.modules["app.core.config"] = stub_config

    spec = importlib.util.spec_from_file_location(
        "app.routers.trending",
        api_root / "app" / "routers" / "trending.py",
    )
    mod = importlib.util.module_from_spec(spec)
    sys.modules["app.routers.trending"] = mod
    spec.loader.exec_module(mod)
    return mod


_trending = _load_trending_module()

_parse_rss = _trending._parse_rss
_STATIC_TOPICS = _trending._STATIC_TOPICS
_TRENDS_TOP_N = _trending._TRENDS_TOP_N
_get_trending_topics = _trending._get_trending_topics


# ── RSS samples ───────────────────────────────────────────────────────────────

VALID_RSS = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:ht="https://trends.google.com/trends/trendingsearches/daily">
  <channel>
    <title>Google Trends</title>
    <item>
      <title>AI Agents</title>
      <ht:approx_traffic>2,000,000+</ht:approx_traffic>
    </item>
    <item>
      <title>Weight Loss Drug</title>
      <ht:approx_traffic>1,500,000+</ht:approx_traffic>
    </item>
    <item>
      <title>Solar Storm 2026</title>
      <ht:approx_traffic>800,000+</ht:approx_traffic>
    </item>
    <item>
      <title>World Cup 2026</title>
      <ht:approx_traffic>600,000+</ht:approx_traffic>
    </item>
    <item>
      <title>Fifth Trend</title>
      <ht:approx_traffic>300,000+</ht:approx_traffic>
    </item>
  </channel>
</rss>
"""

RSS_ONLY_TWO_ITEMS = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item><title>Topic One</title></item>
    <item><title>Topic Two</title></item>
  </channel>
</rss>
"""

RSS_NO_ITEMS = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Empty Feed</title>
  </channel>
</rss>
"""

MALFORMED_XML = "<<this is not xml>>"


# ── RSS parser unit tests ─────────────────────────────────────────────────────

def test_parse_rss_returns_top_4():
    """Parser must cap results at 4 even if RSS has more items."""
    topics = _parse_rss(VALID_RSS)
    assert len(topics) == 4


def test_parse_rss_returns_correct_titles():
    """Parser must extract titles in RSS document order."""
    topics = _parse_rss(VALID_RSS)
    assert topics[0] == "AI Agents"
    assert topics[1] == "Weight Loss Drug"
    assert topics[2] == "Solar Storm 2026"
    assert topics[3] == "World Cup 2026"


def test_parse_rss_with_fewer_than_4_items():
    """Parser must return however many items exist when fewer than 4 available."""
    topics = _parse_rss(RSS_ONLY_TWO_ITEMS)
    assert len(topics) == 2
    assert topics[0] == "Topic One"
    assert topics[1] == "Topic Two"


def test_parse_rss_raises_on_no_items():
    """If the feed has no <item> elements, parser must raise ValueError."""
    with pytest.raises(ValueError, match="No topics found"):
        _parse_rss(RSS_NO_ITEMS)


def test_parse_rss_raises_on_malformed_xml():
    """Malformed XML must raise ET.ParseError (propagated as-is to caller)."""
    with pytest.raises(ET.ParseError):
        _parse_rss(MALFORMED_XML)


# ── Static fallback contract ──────────────────────────────────────────────────

def test_static_topics_has_exactly_4():
    """Static fallback must deliver exactly 4 topics (mirrors RSS top-N count)."""
    assert len(_STATIC_TOPICS) == 4


def test_static_topics_are_nonempty_strings():
    """Each static topic must be a non-empty string."""
    for topic in _STATIC_TOPICS:
        assert isinstance(topic, str)
        assert topic.strip() != ""


# ── Async route tests (mocked HTTP) ──────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_trending_topics_returns_trends_on_success():
    """
    When RSS fetch succeeds, _get_trending_topics must return (topics, "trends")
    with up to 4 items in document order.
    """
    import httpx

    # Reset module-level cache
    _trending._cached_topics = None
    _trending._cached_at = 0.0

    mock_resp = MagicMock()
    mock_resp.text = VALID_RSS
    mock_resp.raise_for_status = lambda: None

    mock_client = AsyncMock()
    mock_client.get = AsyncMock(return_value=mock_resp)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch.object(_trending.httpx, "AsyncClient", return_value=mock_client):
        topics, source = await _get_trending_topics()

    assert source == "trends"
    assert len(topics) == 4
    assert topics[0] == "AI Agents"


@pytest.mark.asyncio
async def test_get_trending_topics_falls_back_on_network_error():
    """
    When the RSS fetch raises a network error, _get_trending_topics must
    return (_STATIC_TOPICS, "static") and never propagate the exception.
    """
    import httpx

    _trending._cached_topics = None
    _trending._cached_at = 0.0

    mock_client = AsyncMock()
    mock_client.get = AsyncMock(
        side_effect=httpx.ConnectError("simulated network failure", request=None)
    )
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch.object(_trending.httpx, "AsyncClient", return_value=mock_client):
        topics, source = await _get_trending_topics()

    assert source == "static"
    assert topics == _STATIC_TOPICS


@pytest.mark.asyncio
async def test_get_trending_topics_falls_back_on_parse_error():
    """
    When the RSS response is malformed XML, _get_trending_topics must
    return (_STATIC_TOPICS, "static") and never propagate the exception.
    """
    _trending._cached_topics = None
    _trending._cached_at = 0.0

    mock_resp = MagicMock()
    mock_resp.text = MALFORMED_XML
    mock_resp.raise_for_status = lambda: None

    mock_client = AsyncMock()
    mock_client.get = AsyncMock(return_value=mock_resp)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch.object(_trending.httpx, "AsyncClient", return_value=mock_client):
        topics, source = await _get_trending_topics()

    assert source == "static"
    assert topics == _STATIC_TOPICS


@pytest.mark.asyncio
async def test_cache_prevents_second_fetch():
    """
    With a warm cache (within TTL), a second call must return the cached value
    and must NOT make another HTTP request.
    """
    import time

    # Pre-warm cache
    _trending._cached_topics = ["Cached 1", "Cached 2", "Cached 3", "Cached 4"]
    _trending._cached_at = time.monotonic()

    fetch_called = False

    mock_client = AsyncMock()

    async def _should_not_call(url, **kwargs):
        nonlocal fetch_called
        fetch_called = True
        raise AssertionError("HTTP fetch called despite warm cache")

    mock_client.get = _should_not_call
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch.object(_trending.httpx, "AsyncClient", return_value=mock_client):
        topics, source = await _get_trending_topics()

    assert not fetch_called, "HTTP fetch must not be called when cache is warm"
    assert source == "trends"
    assert topics == ["Cached 1", "Cached 2", "Cached 3", "Cached 4"]
