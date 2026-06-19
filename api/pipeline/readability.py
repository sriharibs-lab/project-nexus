"""
Mozilla Readability extraction via trafilatura.

trafilatura is the best Python implementation of Readability-style boilerplate removal.
Runs entirely locally — zero cost, no API key, no rate limits.
"""

import time
from typing import Optional

import trafilatura
from trafilatura.settings import use_config

from .base import ContentType, ExtractionResult

# Suppress noisy warnings from trafilatura
_cfg = use_config()
_cfg.set("DEFAULT", "EXTRACTION_TIMEOUT", "10")


def extract(url: str, *, timeout: int = 15) -> ExtractionResult:
    t0 = time.perf_counter()
    try:
        downloaded = trafilatura.fetch_url(url)
        if downloaded is None:
            raise ValueError("Failed to fetch URL (blocked or unreachable)")

        result = trafilatura.extract(
            downloaded,
            include_comments=False,
            include_tables=True,
            no_fallback=False,
            output_format="txt",
            config=_cfg,
        )
        metadata = trafilatura.extract_metadata(downloaded)

        if result is None:
            raise ValueError("Readability extraction returned no content")

        title: Optional[str] = getattr(metadata, "title", None) if metadata else None
        content = result.strip()
        elapsed = (time.perf_counter() - t0) * 1000

        return ExtractionResult(
            extractor="trafilatura (Readability)",
            url=url,
            content_type=ContentType.article,
            title=title,
            content=content,
            word_count=len(content.split()),
            elapsed_ms=elapsed,
            cost_usd=0.0,
            metadata={
                "author": getattr(metadata, "author", None),
                "date": str(getattr(metadata, "date", None)),
                "sitename": getattr(metadata, "sitename", None),
            } if metadata else {},
        )

    except Exception as exc:
        elapsed = (time.perf_counter() - t0) * 1000
        return ExtractionResult(
            extractor="trafilatura (Readability)",
            url=url,
            content_type=ContentType.article,
            title=None,
            content="",
            word_count=0,
            elapsed_ms=elapsed,
            cost_usd=0.0,
            error=str(exc),
        )
