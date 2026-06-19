"""
Jina AI Reader API — article extraction via r.jina.ai.

Converts any URL to clean, LLM-friendly markdown in a single GET request.
Free tier: 1 RPM without key, 200 RPM with JINA_API_KEY.
Paid: ~$0.02 / 1M tokens beyond free quota (~$0.00002 per avg article).

Docs: https://jina.ai/reader
"""

import os
import time
from typing import Optional

import httpx

from .base import ContentType, ExtractionResult

JINA_BASE = "https://r.jina.ai/"
TIMEOUT = 30  # seconds; Jina can be slow on heavy pages


async def extract(url: str) -> ExtractionResult:
    """
    Async extraction via Jina AI Reader.

    Uses httpx.AsyncClient directly (not asyncio.to_thread) to avoid consuming
    a thread-pool slot for up to 30s per request under concurrent ingest load
    (Architect note: converts from sync httpx.get to async).
    """
    api_key: Optional[str] = os.getenv("JINA_API_KEY")

    headers = {
        "Accept": "text/plain",
        "X-Return-Format": "markdown",
        # Suppress image alt-text to reduce noise
        "X-Remove-Selector": "img, .ad, [class*='ad-'], [class*='banner']",
    }
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    t0 = time.perf_counter()
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT, follow_redirects=True) as client:
            resp = await client.get(f"{JINA_BASE}{url}", headers=headers)
        resp.raise_for_status()
        content = resp.text.strip()
        elapsed = (time.perf_counter() - t0) * 1000

        # Jina prepends a metadata block; extract title from it
        title: Optional[str] = None
        lines = content.splitlines()
        for line in lines[:10]:
            if line.startswith("Title:"):
                title = line.replace("Title:", "").strip()
                break

        return ExtractionResult(
            extractor="Jina AI Reader",
            url=url,
            content_type=ContentType.article,
            title=title,
            content=content,
            word_count=len(content.split()),
            elapsed_ms=elapsed,
            cost_usd=0.0,  # well within free tier for testing
            metadata={
                "authenticated": bool(api_key),
                "response_chars": len(content),
            },
        )

    except Exception as exc:
        elapsed = (time.perf_counter() - t0) * 1000
        return ExtractionResult(
            extractor="Jina AI Reader",
            url=url,
            content_type=ContentType.article,
            title=None,
            content="",
            word_count=0,
            elapsed_ms=elapsed,
            cost_usd=0.0,
            error=str(exc),
        )
