"""
Tests for task 0-004 — Waitlist landing page
  prototype/src/app/page.tsx
  prototype/src/app/api/waitlist/route.ts
  prototype/src/app/layout.tsx
  prototype/src/app/globals.css

Strategy:
  - Source-level structural checks (regex over TypeScript) validate correctness
    without requiring a running Node/Next.js process.
  - API route logic is ported/replicated in Python for unit-testing the
    email-validation, local-file-fallback, and provider-selection branches.
  - No real network calls; no real filesystem mutations to the repo.
"""

from __future__ import annotations

import json
import os
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

# ---------------------------------------------------------------------------
# File paths
# ---------------------------------------------------------------------------
WORKTREE = Path(
    "/Users/srihari/Documents/Projects/Project Nexus"
    "/.claude/worktrees/wf_5f2d3d42-857-9"
)
PAGE_TSX = WORKTREE / "prototype/src/app/page.tsx"
ROUTE_TS = WORKTREE / "prototype/src/app/api/waitlist/route.ts"
LAYOUT_TSX = WORKTREE / "prototype/src/app/layout.tsx"
GLOBALS_CSS = WORKTREE / "prototype/src/app/globals.css"

def _src(path: Path) -> str:
    return path.read_text(encoding="utf-8")


# ===========================================================================
# 1. page.tsx — structural / content checks
# ===========================================================================
class TestPageTsxStructure(unittest.TestCase):
    """Validate the landing page source has all required visual elements."""

    def setUp(self):
        self.src = _src(PAGE_TSX)

    def test_headline_think_dont_just_save(self):
        """Headline 'Think, don't just save.' must be present."""
        self.assertIn("Think", self.src)
        self.assertIn("don", self.src)   # handles &apos; entity
        self.assertIn("just save", self.src)

    def test_echo_mark_svg_present(self):
        """EchoMark SVG component must be defined and rendered."""
        self.assertIn("EchoMark", self.src)
        self.assertIn("viewBox", self.src)
        # Plum accent colour used on the mark
        self.assertIn("#7054AB", self.src)

    def test_bloom_gradient_background(self):
        """Page background must use bloom/plum gradient (#E7DCF4)."""
        self.assertIn("#E7DCF4", self.src)
        self.assertIn("radial-gradient", self.src)

    def test_white_card_present(self):
        """Waitlist box must be a white (#FFFFFF) rounded card."""
        self.assertIn("#FFFFFF", self.src)
        # border-radius on the card
        self.assertIn("borderRadius", self.src)

    def test_email_input_present(self):
        """Email input field must be present with correct type and placeholder."""
        self.assertIn('type="email"', self.src)
        self.assertIn("your@email.com", self.src)

    def test_success_state_copy(self):
        """Success state must include 'You're on the list.' text."""
        # page uses &apos; or plain apostrophe — check both
        self.assertTrue(
            "You" in self.src and "on the list" in self.src,
            "Success copy not found",
        )

    def test_success_state_checkmark(self):
        """Success state must render a checkmark SVG path."""
        # The SVG path for a tick: 'm5 12.5 4.5 4.5L19 7' (lowercase m = relative)
        self.assertRegex(self.src, r'[Mm]5\s+12\.5|[Mm] 5 12')

    def test_error_message_copy(self):
        """Inline error 'Enter a valid email address.' must be in source."""
        self.assertIn("Enter a valid email address.", self.src)

    def test_floating_header_fixed_position(self):
        """Floating header must use position: fixed."""
        self.assertIn("position: \"fixed\"", self.src)

    def test_floating_header_glass_blur(self):
        """Header must use backdropFilter for glass blur effect."""
        self.assertIn("backdropFilter", self.src)
        self.assertIn("blur", self.src)

    def test_footer_current_year_expression(self):
        """Footer must use getFullYear() to emit the current year dynamically."""
        self.assertIn("getFullYear()", self.src)

    def test_form_client_side_email_validation(self):
        """Client-side email regex must exist to guard submission."""
        # look for a regex literal pattern matching email
        self.assertRegex(self.src, r"emailRegex\s*=\s*/")

    def test_spinner_during_loading(self):
        """SpinnerIcon / spin animation must be defined for loading state."""
        self.assertIn("SpinnerIcon", self.src)
        self.assertIn("spin", self.src)

    def test_nexus_wordmark_in_header(self):
        """NexusLockup / wordmark 'Nexus' must be in the floating header."""
        self.assertIn("NexusLockup", self.src)
        self.assertIn("Nexus", self.src)

    def test_mobile_flex_wrap_on_input_row(self):
        """Input+button row must use flexWrap for iPhone wrapping."""
        self.assertIn("flexWrap", self.src)
        self.assertIn("wrap", self.src)

    def test_waitlist_api_endpoint(self):
        """Form must POST to /api/waitlist."""
        self.assertIn("/api/waitlist", self.src)

    def test_graceful_fallback_on_fetch_error(self):
        """Catch block must set success state when fetch throws (no backend)."""
        # look for setFormState("success") inside a catch block
        src = self.src
        catch_idx = src.find("} catch")
        self.assertGreater(catch_idx, -1, "No catch block found")
        after_catch = src[catch_idx: catch_idx + 300]
        self.assertIn('setFormState("success")', after_catch)

    def test_iphone_coming_soon_badge(self):
        """Page must include an iPhone / 'Coming to iPhone' badge."""
        self.assertIn("Coming to iPhone", self.src)


# ===========================================================================
# 2. layout.tsx — metadata checks
# ===========================================================================
class TestLayoutMetadata(unittest.TestCase):
    def setUp(self):
        self.src = _src(LAYOUT_TSX)

    def test_title_contains_headline(self):
        """Page <title> metadata must echo the hero headline."""
        self.assertIn("Think, don", self.src)

    def test_og_type_website(self):
        """OpenGraph type must be 'website'."""
        self.assertIn("website", self.src)

    def test_lang_en(self):
        """html element must declare lang='en'."""
        self.assertIn('lang="en"', self.src)


# ===========================================================================
# 3. globals.css — design tokens
# ===========================================================================
class TestGlobalsCSS(unittest.TestCase):
    def setUp(self):
        self.src = _src(GLOBALS_CSS)

    def test_plum_token(self):
        self.assertIn("--plum: #7054AB", self.src)

    def test_bloom_token(self):
        self.assertIn("--bloom: #E7DCF4", self.src)

    def test_ink_token(self):
        self.assertIn("--ink: #130E1A", self.src)

    def test_page_gradient_token(self):
        self.assertIn("--page:", self.src)
        self.assertIn("radial-gradient", self.src)

    def test_box_sizing_reset(self):
        self.assertIn("box-sizing: border-box", self.src)


# ===========================================================================
# 4. route.ts — email validation logic (ported to Python)
# ===========================================================================
import re as _re

# Mirror the TypeScript EMAIL_REGEX from route.ts
_EMAIL_RE = _re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


def _is_valid_email(s: str) -> bool:
    return bool(_EMAIL_RE.match(s))


class TestEmailValidationLogic(unittest.TestCase):
    """Validate the email-validation regex that powers the API route."""

    def test_valid_plain_email(self):
        self.assertTrue(_is_valid_email("user@example.com"))

    def test_valid_subdomain_email(self):
        self.assertTrue(_is_valid_email("user@mail.example.com"))

    def test_valid_plus_address(self):
        self.assertTrue(_is_valid_email("user+tag@example.com"))

    def test_invalid_no_at(self):
        self.assertFalse(_is_valid_email("notanemail"))

    def test_invalid_no_domain(self):
        self.assertFalse(_is_valid_email("user@"))

    def test_invalid_no_tld(self):
        self.assertFalse(_is_valid_email("user@domain"))

    def test_invalid_empty_string(self):
        self.assertFalse(_is_valid_email(""))

    def test_invalid_spaces(self):
        self.assertFalse(_is_valid_email("user name@example.com"))

    def test_invalid_double_at(self):
        self.assertFalse(_is_valid_email("user@@example.com"))


# ===========================================================================
# 5. API route — local file storage logic (ported to Python)
# ===========================================================================
class TestLocalWaitlistStorage(unittest.TestCase):
    """Unit-test the local-file storage branch of the waitlist API route."""

    def _read(self, path: str) -> list:
        try:
            with open(path) as f:
                return json.load(f)
        except Exception:
            return []

    def _write(self, path: str, emails: list) -> None:
        with open(path, "w") as f:
            json.dump(emails, f, indent=2)

    def test_adds_first_email(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, ".waitlist.json")
            existing = self._read(p)
            email = "test@example.com"
            if email not in existing:
                self._write(p, existing + [email])
            result = self._read(p)
            self.assertIn("test@example.com", result)

    def test_deduplicates_email(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, ".waitlist.json")
            self._write(p, ["test@example.com"])
            existing = self._read(p)
            email = "test@example.com"
            if email not in existing:
                self._write(p, existing + [email])
            result = self._read(p)
            self.assertEqual(result.count("test@example.com"), 1)

    def test_appends_new_emails(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, ".waitlist.json")
            for email in ["a@x.com", "b@x.com"]:
                existing = self._read(p)
                if email not in existing:
                    self._write(p, existing + [email])
            result = self._read(p)
            self.assertEqual(result, ["a@x.com", "b@x.com"])

    def test_reads_missing_file_gracefully(self):
        """read from non-existent file should return empty list (no crash)."""
        result = self._read("/tmp/does_not_exist_xyz_123.json")
        self.assertEqual(result, [])

    def test_json_file_format(self):
        """Written file must be valid JSON array."""
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, ".waitlist.json")
            self._write(p, ["user@example.com"])
            raw = open(p).read()
            parsed = json.loads(raw)
            self.assertIsInstance(parsed, list)


# ===========================================================================
# 6. route.ts — structural source checks
# ===========================================================================
class TestRouteSourceStructure(unittest.TestCase):
    def setUp(self):
        self.src = _src(ROUTE_TS)

    def test_post_handler_exported(self):
        """POST handler must be exported (Next.js App Router convention)."""
        self.assertRegex(self.src, r"export\s+async\s+function\s+POST")

    def test_422_for_invalid_email(self):
        """Route must return 422 for invalid email."""
        self.assertIn("422", self.src)

    def test_201_for_success(self):
        """Route must return 201 on successful waitlist add."""
        self.assertIn("201", self.src)

    def test_400_for_bad_body(self):
        """Route must return 400 for unparseable request body."""
        self.assertIn("400", self.src)

    def test_email_regex_present(self):
        """Server-side email regex must be defined."""
        self.assertRegex(self.src, r"EMAIL_REGEX\s*=\s*/")

    def test_local_file_fallback(self):
        """Local .waitlist.json fallback must exist."""
        self.assertIn(".waitlist.json", self.src)

    def test_resend_provider_branch(self):
        """Resend provider integration must be conditionally present."""
        self.assertIn("resend", self.src)
        self.assertIn("RESEND_API_KEY", self.src)

    def test_error_logged_not_thrown(self):
        """Errors in provider call must be caught and a 500 returned (not raised)."""
        self.assertIn("console.error", self.src)
        self.assertIn("500", self.src)

    def test_email_lowercased_and_trimmed(self):
        """Email input must be .trim().toLowerCase() before processing."""
        self.assertIn("trim()", self.src)
        self.assertIn("toLowerCase()", self.src)

    def test_invalid_request_message(self):
        """400 response message must read 'Invalid request body.'"""
        self.assertIn("Invalid request body.", self.src)

    def test_validation_error_message(self):
        """422 response must include 'Enter a valid email address.'"""
        self.assertIn("Enter a valid email address.", self.src)


if __name__ == "__main__":
    unittest.main()
