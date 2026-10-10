"""
Humanized title fallback for items whose ingestion failed before a title was
extracted — a readable name beats a raw URL in the Sources list.

    https://www.cricinfo.com/series/.../live-cricket-score  → "Live Cricket Score"
    https://example.com                                      → "example.com"
"""

from __future__ import annotations

import re
from urllib.parse import unquote, urlsplit

# Path segments that are never a useful title on their own.
_BORING_SEGMENTS = {
    "", "index", "home", "default", "article", "articles", "post", "posts",
    "p", "s", "e", "watch", "status", "story", "stories", "news", "blog", "en", "us",
}
_ACRONYMS = {"ai", "api", "us", "uk", "eu", "un", "nba", "nfl", "ipl", "t20i", "odi", "ios", "tv", "ceo", "gpu", "llm"}
_SMALL_WORDS = {"a", "an", "and", "as", "at", "but", "by", "for", "in", "of", "on", "or", "the", "to", "vs", "v"}


def _host(url: str) -> str:
    host = (urlsplit(url).hostname or "").lower()
    return host[4:] if host.startswith("www.") else host


def _clean_segment(seg: str) -> str:
    seg = unquote(seg)
    seg = re.sub(r"\.[A-Za-z0-9]{1,5}$", "", seg)          # strip .html / .php / .pdf
    seg = re.sub(r"[-_]\d{5,}$", "", seg)                   # trailing numeric ids: -1529231 (years survive)
    seg = re.sub(r"^\d{5,}[-_]", "", seg)                   # leading numeric ids: 1529231-
    seg = re.sub(r"\b\d{5,}\b", " ", seg)                   # long bare numbers anywhere
    seg = re.sub(r"[-_+]+", " ", seg)
    seg = re.sub(r"\s+", " ", seg).strip()
    return seg


def _title_case(text: str) -> str:
    words = text.split(" ")
    out: list[str] = []
    for i, w in enumerate(words):
        lw = w.lower()
        if i > 0 and lw in _SMALL_WORDS:
            out.append(lw)
        elif (w.isupper() and len(w) > 1) or lw in _ACRONYMS:
            out.append(w.upper())  # keep acronyms (T20I, NBA, AI)
        else:
            out.append(w[:1].upper() + w[1:])
    return " ".join(out)


def humanize_url_title(url: str) -> str:
    """Derive a readable title from a URL; falls back to the bare host."""
    try:
        parts = urlsplit(url.strip())
    except ValueError:
        return url.strip()[:120]
    segments = [s for s in parts.path.split("/") if s]
    for seg in reversed(segments):
        if re.sub(r"\.[A-Za-z0-9]{1,5}$", "", seg).lower() in _BORING_SEGMENTS:
            continue  # index.html, /home, /watch … never a title
        cleaned = _clean_segment(seg)
        # Needs at least one alphabetic run of 2+ chars to be a "word".
        if cleaned and re.search(r"[A-Za-z]{2,}", cleaned):
            return _title_case(cleaned)[:120]
    return _host(url) or url.strip()[:120]
