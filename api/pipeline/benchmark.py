#!/usr/bin/env python3
"""
Nexus Content Extraction Pipeline — Benchmark Runner

Tests all four extractors with real URLs and prints a comparison report.

Usage:
    python -m api.pipeline.benchmark
    # or from api/ directory:
    python pipeline/benchmark.py

Env vars (optional — extractors degrade gracefully without them):
    JINA_API_KEY       — higher Jina rate limits (200 RPM vs 1 RPM)
    YOUTUBE_API_KEY    — enriches YouTube results with metadata
    DEEPGRAM_API_KEY   — required for Deepgram; skipped if absent
"""

import os
import sys
import textwrap
from typing import Optional

# Allow running as script or as module
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

from api.pipeline import readability, jina, youtube
from api.pipeline import deepgram_extractor as deepgram
from api.pipeline.base import ExtractionResult

# ─── Test targets ────────────────────────────────────────────────────────────

ARTICLE_URL = "https://paulgraham.com/greatwork.html"

# Sam Altman's "How to be Successful" blog post on YC — short, clean, reliable
ARTICLE_URL_2 = "https://blog.samaltman.com/how-to-be-successful"

# Lex Fridman Podcast #431 — Elon Musk (has official captions)
YOUTUBE_URL = "https://www.youtube.com/watch?v=JN3KPFbWCy8"

# Gettysburg Address read aloud — LibriVox public domain MP3 (~2min, 2.4MB)
# Good benchmark: clear speech, known content, easy to judge accuracy
AUDIO_URL = "https://ia800300.us.archive.org/26/items/gettysburg_address_librivox/gettysburgaddress_01_lincoln.mp3"

# ─── Report helpers ──────────────────────────────────────────────────────────

RESET = "\033[0m"
BOLD  = "\033[1m"
GREEN = "\033[32m"
RED   = "\033[31m"
CYAN  = "\033[36m"
DIM   = "\033[2m"
YELLOW = "\033[33m"


def _status(r: ExtractionResult) -> str:
    if r.ok:
        return f"{GREEN}OK{RESET}"
    return f"{RED}FAIL{RESET}"


def _cost(r: ExtractionResult) -> str:
    if r.cost_usd is None:
        return "N/A (key missing)"
    if r.cost_usd == 0.0:
        return "free"
    return f"${r.cost_usd:.6f}"


def _bar(value: float, max_val: float, width: int = 20) -> str:
    if max_val == 0:
        return " " * width
    filled = int((value / max_val) * width)
    return "█" * filled + "░" * (width - filled)


def print_report(results: list[ExtractionResult]) -> None:
    print(f"\n{BOLD}{'═' * 80}{RESET}")
    print(f"{BOLD}  Project Nexus — Extraction Pipeline Benchmark{RESET}")
    print(f"{BOLD}{'═' * 80}{RESET}\n")

    max_words = max((r.word_count for r in results if r.ok), default=1)
    max_ms    = max((r.elapsed_ms for r in results), default=1)

    for r in results:
        print(f"{BOLD}{CYAN}{r.extractor}{RESET}  [{_status(r)}]")
        print(f"  URL     : {DIM}{r.url[:80]}{RESET}")
        print(f"  Title   : {r.title or DIM+'(not extracted)'+RESET}")

        if r.ok:
            bar_w = _bar(r.word_count, max_words)
            bar_t = _bar(r.elapsed_ms, max_ms)
            print(f"  Words   : {r.word_count:>6,}  {bar_w}")
            print(f"  Time    : {r.elapsed_ms:>6.0f}ms {bar_t}")
            print(f"  Cost    : {_cost(r)}")

            if r.metadata:
                meta_str = "  ".join(f"{k}={v}" for k, v in r.metadata.items() if v is not None)
                print(f"  Meta    : {DIM}{meta_str[:100]}{RESET}")

            preview = textwrap.fill(r.preview(400), width=72, initial_indent="  ", subsequent_indent="  ")
            print(f"\n{DIM}{preview}{RESET}\n")
        else:
            print(f"  {RED}Error   : {r.error}{RESET}\n")

        print(f"  {DIM}{'─' * 76}{RESET}")

    # Summary table
    print(f"\n{BOLD}  Summary{RESET}")
    print(f"  {'Extractor':<30} {'Status':<8} {'Words':>8} {'ms':>8} {'Cost/call':<20}")
    print(f"  {'─'*30} {'─'*8} {'─'*8} {'─'*8} {'─'*20}")
    for r in results:
        status = "OK" if r.ok else "FAIL"
        words  = f"{r.word_count:,}" if r.ok else "—"
        ms     = f"{r.elapsed_ms:.0f}" if r.ok else "—"
        cost   = _cost(r)
        print(f"  {r.extractor:<30} {status:<8} {words:>8} {ms:>8} {cost:<20}")

    print(f"\n{BOLD}{'═' * 80}{RESET}\n")


# ─── Recommendation note ─────────────────────────────────────────────────────

RECOMMENDATION = """
RECOMMENDATION FOR V1
─────────────────────
Article extraction  → Jina AI Reader (primary) + trafilatura (fallback)
  Jina returns clean markdown ready for the LLM; no parsing required.
  trafilatura as zero-cost fallback when Jina rate-limits or paywalls block.

YouTube             → youtube-transcript-api (free, no key, instant)
  Upgrade path: YouTube Data API v3 for metadata enrichment once needed.

Podcasts            → Deepgram Nova-3
  Best accuracy/speed ratio in the market. ~$0.0043/min is acceptable for
  premium users. Batch-transcribe in background; show progress to user.

V1 pipeline priority: Jina → trafilatura → YouTube-transcript → Deepgram
"""


# ─── Main ────────────────────────────────────────────────────────────────────

def main() -> None:
    print(f"\n{BOLD}Running extraction tests...{RESET} (this may take 15–60s)\n")

    results: list[ExtractionResult] = []

    # 1. trafilatura
    print(f"  {DIM}[1/4] trafilatura (Readability)...{RESET}")
    results.append(readability.extract(ARTICLE_URL))

    # 2. Jina AI Reader
    print(f"  {DIM}[2/4] Jina AI Reader...{RESET}")
    results.append(jina.extract(ARTICLE_URL))

    # 3. YouTube transcript
    print(f"  {DIM}[3/4] YouTube Transcript API...{RESET}")
    results.append(youtube.extract(YOUTUBE_URL))

    # 4. Deepgram
    print(f"  {DIM}[4/4] Deepgram Nova-3 (audio transcription)...{RESET}")
    results.append(deepgram.extract(AUDIO_URL))

    print_report(results)
    print(RECOMMENDATION)


if __name__ == "__main__":
    main()
