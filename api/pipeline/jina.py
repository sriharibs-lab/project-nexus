"""
Jina AI Reader API — article extraction via r.jina.ai.

Converts any URL to clean, LLM-friendly markdown in a single GET request.
Free tier: 1 RPM without key, 200 RPM with JINA_API_KEY.
Paid: ~$0.02 / 1M tokens beyond free quota (~$0.00002 per avg article).

Docs: https://jina.ai/reader

Performance notes (1D-005 save-to-summary SLO < 10s):
  - connect_timeout=5s: reject slow DNS / TCP hangs early.
  - read_timeout set by JINA_TIMEOUT env var (default 8s).
  - Together this caps Jina at ~13s worst-case but in practice 2-5s for
    typical articles. Caller (ingestion.py) applies the fallback if this
    returns an error.
  - Uses httpx.AsyncClient so the event loop is not blocked during I/O.
"""

from __future__ import annotations

import logging
import os
import time
from typing import Optional

import httpx

from .base import ContentType, ExtractionResult

logger = logging.getLogger(__name__)

JINA_BASE = "https://r.jina.ai/"

# Timeouts tuned for save-to-summary SLO < 10 000 ms (SPEC §9b).
# Connect timeout is short — if Jina's servers aren't responding in 5s,
# we should fail-fast and hand off to trafilatura fallback.
# Read timeout can be longer because Jina sometimes fetches heavy pages.
# Both values are overridable via JINA_CONNECT_TIMEOUT / JINA_READ_TIMEOUT
# env vars to allow production tuning without code changes.
_DEFAULT_CONNECT_TIMEOUT = 5   # seconds
_DEFAULT_READ_TIMEOUT = 8      # seconds — leaves ~2s for AI + DB in 10s SLO


def _get_timeout() -> httpx.Timeout:
    connect_t = float(os.getenv("JINA_CONNECT_TIMEOUT", str(_DEFAULT_CONNECT_TIMEOUT)))
    read_t = float(os.getenv("JINA_READ_TIMEOUT", str(_DEFAULT_READ_TIMEOUT)))
    return httpx.Timeout(connect=connect_t, read=read_t, write=5.0, pool=5.0)


async def extract(url: str) -> ExtractionResult:
    """
    Fetch clean article markdown from Jina AI Reader.

    Returns ExtractionResult with error set (not raised) on failure so the
    caller can transparently fall back to trafilatura without try/except.
    """
    api_key: Optional[str] = os.getenv("JINA_API_KEY")

    headers = {
        "Accept": "text/plain",
        "X-Return-Format": "markdown",
        # Suppress image alt-text and ads to reduce noise in the AI prompt.
        "X-Remove-Selector": "img, .ad, [class*='ad-'], [class*='banner']",
    }
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    timeout = _get_timeout()
    t0 = time.perf_counter()
    try:
        async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
            resp = await client.get(f"{JINA_BASE}{url}", headers=headers)
        resp.raise_for_status()
        content = resp.text.strip()
        elapsed = (time.perf_counter() - t0) * 1000

        # Jina prepends a metadata block; extract title from it.
        title: Optional[str] = None
        lines = content.splitlines()
        for line in lines[:10]:
            if line.startswith("Title:"):
                title = line.replace("Title:", "").strip()
                break

        logger.info(
            "jina.extract ok url=%s elapsed_ms=%.0f chars=%d authenticated=%s",
            url, elapsed, len(content), bool(api_key),
        )

        return ExtractionResult(
            extractor="Jina AI Reader",
            url=url,
            content_type=ContentType.ARTICLE,
            title=title,
            content=content,
            word_count=len(content.split()),
            elapsed_ms=elapsed,
            cost_usd=0.0,  # well within free tier for article volumes
            metadata={
                "authenticated": bool(api_key),
                "response_chars": len(content),
                "connect_timeout_s": timeout.connect,
                "read_timeout_s": timeout.read,
            },
        )

    except httpx.TimeoutException as exc:
        elapsed = (time.perf_counter() - t0) * 1000
        logger.warning(
            "jina.extract timeout url=%s elapsed_ms=%.0f exc=%s",
            url, elapsed, exc,
        )
        return ExtractionResult(
            extractor="Jina AI Reader",
            url=url,
            content_type=ContentType.ARTICLE,
            title=None,
            content="",
            word_count=0,
            elapsed_ms=elapsed,
            cost_usd=0.0,
            error=f"Timeout after {elapsed:.0f}ms: {exc}",
        )

    except Exception as exc:
        elapsed = (time.perf_counter() - t0) * 1000
        logger.warning("jina.extract error url=%s elapsed_ms=%.0f exc=%s", url, elapsed, exc)
        return ExtractionResult(
            extractor="Jina AI Reader",
            url=url,
            content_type=ContentType.ARTICLE,
            title=None,
            content="",
            word_count=0,
            elapsed_ms=elapsed,
            cost_usd=0.0,
            error=str(exc),
        )
