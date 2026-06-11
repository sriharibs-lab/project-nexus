"""
YouTube transcript extraction via youtube-transcript-api.

No API key required. Fetches official captions or auto-generated transcripts
directly from YouTube's internal endpoint. Includes optional YouTube Data API v3
call for full video metadata (title, channel, duration, description).

Costs:
  - Transcript fetch: free (no quota)
  - YouTube Data API v3 metadata: free up to 10,000 units/day; videos.list = 1 unit/call
"""

import os
import re
import time
from typing import Optional

import httpx
from youtube_transcript_api import YouTubeTranscriptApi, NoTranscriptFound, TranscriptsDisabled, CouldNotRetrieveTranscript

from .base import ContentType, ExtractionResult

YOUTUBE_API_BASE = "https://www.googleapis.com/youtube/v3"


def _extract_video_id(url: str) -> str:
    patterns = [
        r"(?:v=|youtu\.be/|embed/|shorts/)([A-Za-z0-9_-]{11})",
    ]
    for pattern in patterns:
        m = re.search(pattern, url)
        if m:
            return m.group(1)
    raise ValueError(f"Cannot extract video ID from: {url}")


def _fetch_metadata(video_id: str, api_key: str) -> dict:
    resp = httpx.get(
        f"{YOUTUBE_API_BASE}/videos",
        params={
            "part": "snippet,contentDetails,statistics",
            "id": video_id,
            "key": api_key,
        },
        timeout=10,
    )
    resp.raise_for_status()
    items = resp.json().get("items", [])
    if not items:
        return {}
    item = items[0]
    snippet = item.get("snippet", {})
    return {
        "title": snippet.get("title"),
        "channel": snippet.get("channelTitle"),
        "published_at": snippet.get("publishedAt"),
        "description": snippet.get("description", "")[:500],
        "duration": item.get("contentDetails", {}).get("duration"),
        "view_count": item.get("statistics", {}).get("viewCount"),
    }


def extract(url: str, language: str = "en") -> ExtractionResult:
    api_key: Optional[str] = os.getenv("YOUTUBE_API_KEY")
    t0 = time.perf_counter()

    try:
        video_id = _extract_video_id(url)

        # v1.2+ API: instance-based, not class method
        api = YouTubeTranscriptApi()
        fetched = api.fetch(video_id, languages=[language, "en"])
        snippets = list(fetched)

        # Merge segments into clean text
        raw_segments = [s.text.strip() for s in snippets]
        content = " ".join(raw_segments)

        # Timestamped version for context (primary output for Nexus)
        timestamped = "\n".join(
            f"[{int(s.start//60):02d}:{int(s.start%60):02d}] {s.text.strip()}"
            for s in snippets
        )

        # Fetch metadata from Data API if key is present
        metadata: dict = {"video_id": video_id, "authenticated": bool(api_key)}
        title: Optional[str] = None
        if api_key:
            meta = _fetch_metadata(video_id, api_key)
            title = meta.get("title")
            metadata.update(meta)

        elapsed = (time.perf_counter() - t0) * 1000
        return ExtractionResult(
            extractor="YouTube Transcript API",
            url=url,
            content_type=ContentType.VIDEO,
            title=title,
            content=timestamped,  # timestamped version as primary output
            word_count=len(content.split()),
            elapsed_ms=elapsed,
            cost_usd=0.0,
            metadata=metadata,
        )

    except (NoTranscriptFound, TranscriptsDisabled, CouldNotRetrieveTranscript) as exc:
        elapsed = (time.perf_counter() - t0) * 1000
        return ExtractionResult(
            extractor="YouTube Transcript API",
            url=url,
            content_type=ContentType.VIDEO,
            title=None,
            content="",
            word_count=0,
            elapsed_ms=elapsed,
            cost_usd=0.0,
            error=f"No transcript available: {exc}",
        )

    except Exception as exc:
        elapsed = (time.perf_counter() - t0) * 1000
        return ExtractionResult(
            extractor="YouTube Transcript API",
            url=url,
            content_type=ContentType.VIDEO,
            title=None,
            content="",
            word_count=0,
            elapsed_ms=elapsed,
            cost_usd=0.0,
            error=str(exc),
        )
