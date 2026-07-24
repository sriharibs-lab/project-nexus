"""
GET /v1/trending — Curated trending topics for the FRE new-collection chips.

Google Trends' public RSS is deprecated/dead, and raw trending feeds surface
noise (movies, obituaries, disambiguation pages) that make poor "start a research
collection" seeds. So we combine two free, no-key real-time signals —

    1. Wikipedia most-read articles (yesterday)          — what people look up
    2. Hacker News top stories                           — what people discuss

— and pass them through ONE cheap Claude Haiku call that drops the junk and
reframes the rest into sharp, research-worthy topics. Result is cached ~12h, so
the cost is a fraction of a cent per day.

Unauthenticated: called at FRE load, before sign-in. All fields are safe.

Response: {"topics": ["Nolan's Odyssey adaptation", ...], "source": "curated|static"}
Fallback: a curated static list if the signals or Haiku curation are unavailable.
"""

from __future__ import annotations

import asyncio
import datetime
import logging
import time
from typing import Literal

import httpx
from fastapi import APIRouter
from pydantic import BaseModel

from app.core.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/trending", tags=["trending"])

# ── Real-time signal sources (free, no API key) ───────────────────────────────
_WIKI_URL = "https://wikimedia.org/api/rest_v1/metrics/pageviews/top/en.wikipedia/all-access/{y}/{m:02d}/{d:02d}"
_HN_TOP_URL = "https://hacker-news.firebaseio.com/v0/topstories.json"
_HN_ITEM_URL = "https://hacker-news.firebaseio.com/v0/item/{id}.json"

# Wikipedia noise filters — drop non-article namespaces and meta/list pages.
_WIKI_SKIP_PREFIX = (
    "Main_Page", "Special:", "Wikipedia:", "Portal:", "Help:", "Category:",
    "Template:", "File:", "Talk:", "User:", "Draft:",
)
_WIKI_SKIP_SUBSTR = ("Deaths_in_", "List_of_", "_(disambiguation)")

_FETCH_TIMEOUT = 8.0                 # cold-cache fetch budget (cached 12h after)
_CACHE_TTL_SECONDS = 12 * 60 * 60    # curate at most ~2x/day

# ── In-process TTL cache ──────────────────────────────────────────────────────
_cache_lock = asyncio.Lock()
_cached_topics: list[str] | None = None
_cached_at: float = 0.0  # time.monotonic()

# ── Static fallback (shown only if signals/curation unavailable) ──────────────
_STATIC_TOPICS: list[str] = [
    "Artificial Intelligence",
    "Climate & Sustainability",
    "Startups & Venture Capital",
    "Health & Longevity",
]


class TrendingResponse(BaseModel):
    topics: list[str]
    source: Literal["curated", "static"]


# ── Signal fetchers ───────────────────────────────────────────────────────────

async def _fetch_wikipedia_top(client: httpx.AsyncClient, limit: int = 22) -> list[str]:
    """Yesterday's most-read English Wikipedia articles (today's data is partial),
    filtered to real article titles."""
    d = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=1)
    resp = await client.get(_WIKI_URL.format(y=d.year, m=d.month, d=d.day))
    resp.raise_for_status()
    articles = resp.json()["items"][0]["articles"]
    out: list[str] = []
    for a in articles:
        title = a.get("article", "")
        if not title or title.startswith(_WIKI_SKIP_PREFIX):
            continue
        if ":" in title or any(s in title for s in _WIKI_SKIP_SUBSTR):
            continue
        out.append(title.replace("_", " "))
        if len(out) >= limit:
            break
    return out


async def _fetch_hn_top(client: httpx.AsyncClient, limit: int = 12) -> list[str]:
    """Top Hacker News story titles (tech/ideas signal)."""
    resp = await client.get(_HN_TOP_URL)
    resp.raise_for_status()
    ids = resp.json()[:limit]

    async def _title(story_id: int) -> str | None:
        try:
            r = await client.get(_HN_ITEM_URL.format(id=story_id))
            return (r.json() or {}).get("title")
        except Exception:
            return None

    titles = await asyncio.gather(*(_title(i) for i in ids))
    return [t for t in titles if t]


async def _gather_signals(client: httpx.AsyncClient) -> list[str]:
    """Pull both signal sources concurrently; a failure in one is non-fatal."""
    wiki, hn = await asyncio.gather(
        _fetch_wikipedia_top(client),
        _fetch_hn_top(client),
        return_exceptions=True,
    )
    signals: list[str] = []
    if isinstance(wiki, list):
        signals += wiki
    else:
        logger.warning("trending: wikipedia signal failed: %s", wiki)
    if isinstance(hn, list):
        signals += hn
    else:
        logger.warning("trending: hacker news signal failed: %s", hn)
    return signals


async def _get_trending_topics() -> tuple[list[str], Literal["curated", "static"]]:
    """Return (topics, source) with a 12h TTL cache. Concurrent cold-cache
    callers share one fetch via the async lock."""
    global _cached_topics, _cached_at

    now = time.monotonic()
    if _cached_topics is not None and (now - _cached_at) < _CACHE_TTL_SECONDS:
        return _cached_topics, "curated"

    async with _cache_lock:
        now = time.monotonic()
        if _cached_topics is not None and (now - _cached_at) < _CACHE_TTL_SECONDS:
            return _cached_topics, "curated"

        try:
            async with httpx.AsyncClient(
                timeout=_FETCH_TIMEOUT,
                follow_redirects=True,
                headers={"User-Agent": "Nexus/1.0 (content-curation; +https://nexus.app)"},
            ) as client:
                signals = await _gather_signals(client)

            if signals:
                from ai.pipeline import curate_trending_topics
                topics = await curate_trending_topics(signals)
                if topics:
                    _cached_topics = topics
                    _cached_at = time.monotonic()
                    logger.info("trending: curated %d topics from %d signals", len(topics), len(signals))
                    return topics, "curated"

            logger.warning("trending: no curated topics (signals=%d) — static fallback", len(signals))
            return _STATIC_TOPICS, "static"
        except Exception as exc:
            logger.warning("trending: fetch/curation failed (%s) — static fallback", exc)
            return _STATIC_TOPICS, "static"


@router.get(
    "",
    summary="Curated trending topics for the FRE new-collection chips",
    description=(
        "Returns ~6 research-worthy trending topics, distilled by Claude Haiku "
        "from Wikipedia most-read + Hacker News top stories. Falls back to a "
        "curated static list. No authentication required."
    ),
    response_model=TrendingResponse,
)
async def get_trending_topics() -> TrendingResponse:
    topics, source = await _get_trending_topics()
    return TrendingResponse(topics=topics, source=source)
