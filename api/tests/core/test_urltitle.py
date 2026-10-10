"""humanize_url_title — readable fallback titles for failed ingests."""

import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../../")))

from app.core.urltitle import humanize_url_title  # noqa: E402


def test_cricinfo_live_score_path():
    url = (
        "https://www.cricinfo.com/series/west-indies-in-india-2026-27-1529215/"
        "india-vs-west-indies-2nd-t20i-1529231/live-cricket-score"
    )
    assert humanize_url_title(url) == "Live Cricket Score"


def test_bare_host_strips_www():
    assert humanize_url_title("https://www.example.com") == "example.com"
    assert humanize_url_title("https://example.com/") == "example.com"


def test_strips_extension_and_numeric_ids():
    assert humanize_url_title("https://site.com/posts/2026/10/01/why-rust-wins-48213.html") == "Why Rust Wins"
    assert humanize_url_title("https://site.com/a/12345678-the-big-reveal") == "The Big Reveal"


def test_skips_boring_trailing_segments_and_keeps_acronyms():
    assert humanize_url_title("https://blog.io/the-state-of-ai-in-2026/index.html") == "The State of AI in 2026"
    assert humanize_url_title("https://news.site/story/NBA-finals-recap/") == "NBA Finals Recap"


def test_numeric_only_path_falls_back_to_host():
    assert humanize_url_title("https://www.youtube.com/watch?v=abc123") == "youtube.com"
    assert humanize_url_title("https://t.co/9988776655") == "t.co"
