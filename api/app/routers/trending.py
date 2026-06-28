"""
GET /v1/trending — Top trending topics for FRE onboarding chip row.

Fetches the top 4 trending search queries from the Google Trends RSS daily
trending feed for the US (no API key required, publicly available XML feed).

The response is intentionally unauthenticated: it is called at FRE load time,
before the user has signed in. All fields are safe to return to any caller.

Response:
    {"topics": ["AI Agents", "Weight Loss Drug", ...], "source": "trends|static"}

Fallback chain:
    1. Google Trends RSS (rss.google.com) — real-time, no key
    2. Static curated list — if RSS unreachable, malformed, or times out

Caching: a simple in-process TTL cache reduces latency for concurrent FRE
sessions (default 15 minutes, tunable via TRENDING_CACHE_TTL env var).
Resets on process restart — good enough for FRE.
"""

from __future__ import annotations

import asyncio
import logging
import time
import xml.etree.ElementTree as ET
from typing import Literal

import httpx
from fastapi import APIRouter
from pydantic import BaseModel

from app.core.config import settings

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/trending", tags=["trending"])

# ── Google Trends RSS ─────────────────────────────────────────────────────────
# Daily trending searches for the US, no API key.
# Format: RSS 2.0 XML, <item><title>...</title></item> per trend
_TRENDS_RSS_URL = "https://trends.google.com/trends/trendingsearches/daily/rss?geo=US"
_TRENDS_TOP_N = 4
_FETCH_TIMEOUT = 5.0  # seconds — must be fast; FRE must not feel slow

# ── In-process TTL cache ──────────────────────────────────────────────────────
_cache_lock = asyncio.Lock()
_cached_topics: list[str] | None = None
_cached_at: float = 0.0  # epoch seconds

# ── Static fallback ───────────────────────────────────────────────────────────
# Curated list: broad enough to be relevant for most users.
# These are shown only when RSS is unavailable.
_STATIC_TOPICS: list[str] = [
    "Artificial Intelligence",
    "Climate & Sustainability",
    "Startups & Venture Capital",
    "Health & Longevity",
]


# ── Response model ────────────────────────────────────────────────────────────

class TrendingResponse(BaseModel):
    topics: list[str]
    source: Literal["trends", "static"]


# ── Fetch helpers ─────────────────────────────────────────────────────────────


def _parse_rss(xml_text: str) -> list[str]:
    """
    Extract trend titles from Google Trends RSS XML.

    Returns up to _TRENDS_TOP_N topic strings, stripping trailing numbers
    that the RSS sometimes appends (e.g. "Taylor Swift 500,000+").
    Raises ValueError / ET.ParseError on malformed input so the caller
    can fall back gracefully.
    """
    root = ET.fromstring(xml_text)

    # Namespace used by Google Trends for the ht:* extensions
    ns = {"ht": "https://trends.google.com/trends/trendingsearches/daily"}

    topics: list[str] = []

    # Standard RSS: <channel><item><title>...</title></item></channel>
    # Google Trends also has <ht:title> but plain <title> works fine.
    for item in root.iter("item"):
        if len(topics) >= _TRENDS_TOP_N:
            break
        title_el = item.find("title")
        if title_el is not None and title_el.text:
            topic = title_el.text.strip()
            if topic:
                topics.append(topic)

    if not topics:
        raise ValueError("No topics found in RSS feed")

    return topics


async def _fetch_from_google_trends() -> list[str]:
    """
    Fetch trending topics from Google Trends RSS.

    Returns up to _TRENDS_TOP_N topics.
    Raises on network error, timeout, parse error, or HTTP error.
    All exceptions are expected and should be caught by the caller.
    """
    async with httpx.AsyncClient(
        timeout=httpx.Timeout(connect=3.0, read=_FETCH_TIMEOUT, write=3.0, pool=3.0),
        follow_redirects=True,
        headers={"User-Agent": "Nexus/1.0 (content-curation; +https://nexus.app)"},
    ) as client:
        resp = await client.get(_TRENDS_RSS_URL)
        resp.raise_for_status()
        return _parse_rss(resp.text)


async def _get_trending_topics() -> tuple[list[str], Literal["trends", "static"]]:
    """
    Return (topics, source) with TTL cache.

    Cache TTL is controlled by settings.trending_cache_ttl_seconds (default 900s / 15 min).
    Concurrent requests that arrive during a cold cache all wait for the single
    fetch (async lock) rather than stampeding Google Trends.
    """
    global _cached_topics, _cached_at

    ttl = settings.trending_cache_ttl_seconds
    now = time.monotonic()

    # Fast path: cache hit (no lock needed for a read if still valid)
    if _cached_topics is not None and (now - _cached_at) < ttl:
        return _cached_topics, "trends"

    # Slow path: acquire lock, re-check (another coroutine may have refreshed)
    async with _cache_lock:
        if _cached_topics is not None and (now - _cached_at) < ttl:
            return _cached_topics, "trends"

        try:
            topics = await _fetch_from_google_trends()
            _cached_topics = topics
            _cached_at = time.monotonic()
            logger.info("trending: refreshed from Google Trends RSS, topics=%r", topics)
            return topics, "trends"
        except Exception as exc:
            # Network / parse failure: log and fall back
            logger.warning("trending: RSS fetch failed (%s), using static fallback", exc)
            # Intentionally do NOT update _cached_topics — a future request may
            # succeed once the error clears (e.g. transient network hiccup).
            return _STATIC_TOPICS, "static"


# ── Route ─────────────────────────────────────────────────────────────────────


@router.get(
    "",
    summary="Top trending topics for FRE onboarding",
    description=(
        "Returns up to 4 trending search topics from Google Trends RSS. "
        "Falls back to a curated static list if the feed is unavailable. "
        "No authentication required — safe to call before sign-in."
    ),
    response_model=TrendingResponse,
)
async def get_trending_topics() -> TrendingResponse:
    """
    GET /v1/trending

    No auth required. Called at FRE load time before the user signs in.

    Response:
        {"topics": ["AI Agents", "Weight Loss", ...], "source": "trends"}
        {"topics": ["Artificial Intelligence", ...],  "source": "static"}
    """
    topics, source = await _get_trending_topics()
    return TrendingResponse(topics=topics, source=source)
