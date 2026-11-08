"""
Tests for GET /v1/trending internals (originally task 1F-007).

The router was rewritten (2026-10) from Google Trends RSS to Wikipedia most-read
+ Hacker News top stories curated by one Haiku call. The old `_parse_rss` tests
were deleted with that code; these cover the current contract:

  1. Static fallback list has exactly 4 non-empty strings.
  2. Wikipedia signal filtering drops namespaces / meta pages and un-snakes titles.
  3. `_gather_signals` tolerates one failing source.
  4. `_get_trending_topics` returns ("curated") when signals + curation succeed.
  5. It falls back to (_STATIC_TOPICS, "static") on network error or empty curation.
  6. The in-process cache prevents a second fetch within TTL.

Run with:
    cd api && uv run pytest tests/test_1f007_trending.py -v
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import pytest

import app.routers.trending as trending


@pytest.fixture(autouse=True)
def _reset_cache():
    trending._cached_topics = None
    trending._cached_at = 0.0
    yield
    trending._cached_topics = None
    trending._cached_at = 0.0


def _json_response(payload):
    resp = MagicMock()
    resp.json.return_value = payload
    resp.raise_for_status.return_value = None
    return resp


# ── Static fallback ───────────────────────────────────────────────────────────

def test_static_topics_has_exactly_4():
    assert len(trending._STATIC_TOPICS) == 4


def test_static_topics_are_nonempty_strings():
    for topic in trending._STATIC_TOPICS:
        assert isinstance(topic, str) and topic.strip()


# ── Wikipedia filtering ───────────────────────────────────────────────────────

async def test_fetch_wikipedia_top_filters_noise():
    articles = [
        {"article": "Main_Page"},
        {"article": "Special:Search"},
        {"article": "Deaths_in_2026"},
        {"article": "List_of_things"},
        {"article": "Foo_(disambiguation)"},
        {"article": "Quantum_computing"},
        {"article": "Nolan_Odyssey"},
    ]
    client = MagicMock()
    client.get = AsyncMock(return_value=_json_response({"items": [{"articles": articles}]}))

    out = await trending._fetch_wikipedia_top(client, limit=10)

    assert out == ["Quantum computing", "Nolan Odyssey"]


async def test_fetch_wikipedia_top_respects_limit():
    articles = [{"article": f"Topic_{i}"} for i in range(30)]
    client = MagicMock()
    client.get = AsyncMock(return_value=_json_response({"items": [{"articles": articles}]}))

    out = await trending._fetch_wikipedia_top(client, limit=5)

    assert len(out) == 5


# ── Signal gathering ──────────────────────────────────────────────────────────

async def test_gather_signals_tolerates_one_failure():
    with patch.object(trending, "_fetch_wikipedia_top", AsyncMock(side_effect=httpx.ConnectError("down"))), \
         patch.object(trending, "_fetch_hn_top", AsyncMock(return_value=["HN story"])):
        signals = await trending._gather_signals(MagicMock())

    assert signals == ["HN story"]


# ── _get_trending_topics ──────────────────────────────────────────────────────

async def test_get_trending_topics_returns_curated_on_success():
    curated = ["A", "B", "C", "D", "E", "F"]
    with patch.object(trending, "_gather_signals", AsyncMock(return_value=["raw1", "raw2"])), \
         patch("ai.pipeline.curate_trending_topics", AsyncMock(return_value=curated)):
        topics, source = await trending._get_trending_topics()

    assert source == "curated"
    assert topics == curated


async def test_get_trending_topics_falls_back_on_network_error():
    with patch.object(trending, "_gather_signals", AsyncMock(side_effect=httpx.ConnectError("boom"))):
        topics, source = await trending._get_trending_topics()

    assert source == "static"
    assert topics == trending._STATIC_TOPICS


async def test_get_trending_topics_falls_back_when_curation_empty():
    with patch.object(trending, "_gather_signals", AsyncMock(return_value=["raw"])), \
         patch("ai.pipeline.curate_trending_topics", AsyncMock(return_value=[])):
        topics, source = await trending._get_trending_topics()

    assert source == "static"
    assert topics == trending._STATIC_TOPICS


async def test_cache_prevents_second_fetch():
    gather = AsyncMock(return_value=["raw"])
    curate = AsyncMock(return_value=["X", "Y", "Z", "W"])
    with patch.object(trending, "_gather_signals", gather), \
         patch("ai.pipeline.curate_trending_topics", curate):
        first = await trending._get_trending_topics()
        second = await trending._get_trending_topics()

    assert first == second == (["X", "Y", "Z", "W"], "curated")
    assert gather.await_count == 1
    assert curate.await_count == 1
