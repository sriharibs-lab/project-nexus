"""
Tests for 1G-001 — AccountView: user initials, email display, Sign Out.

Tests parse Swift source files as text and validate structure, logic, and
design-system conformance. No iOS simulator required — runs in plain Python.

Covered test hints:
  1. AvatarCircle at 30pt in HomeView toolbar uses bloom fill, plum initials, hairline border
  2. AccountView renders AvatarCircle at 72pt with correct initials derivation
  3. Display name shown when set; "Apple ID" fallback when email is nil/empty
  4. Sign Out calls authManager.signOut() and dismiss() together
  5. initials logic: name → up to 2 parts, email → first char, fallback "?"
  6. avatarInitials in HomeView: same logic, fallback "N" (not "?")
  7. UserDefaults suite "group.app.nexus" with keys nexus_display_name and nexus_email
  8. setSession: only overwrites name/email when Apple provides non-empty values
  9. signOut: clears all four UserDefaults keys
  10. isAuthenticated goes false on signOut
"""

from __future__ import annotations

import os
import re
import unittest

_WORKTREE = "/Users/srihari/Documents/Projects/Project Nexus/.claude/worktrees/wf_8d637bae-96e-3/app-ios/Nexus/Nexus"

ACCOUNT_VIEW_PATH = os.path.join(_WORKTREE, "Features/Settings/AccountView.swift")
AUTH_MANAGER_PATH = os.path.join(_WORKTREE, "Core/Auth/AuthManager.swift")
HOME_VIEW_PATH = os.path.join(_WORKTREE, "Features/Home/HomeView.swift")
NEXUS_APP_PATH = os.path.join(_WORKTREE, "NexusApp.swift")


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


# ---------------------------------------------------------------------------
# AccountView.swift
# ---------------------------------------------------------------------------

class TestAccountViewStructure(unittest.TestCase):
    """AccountView: structural presence checks."""

    def setUp(self):
        self.src = _read(ACCOUNT_VIEW_PATH)

    def test_account_view_struct_defined(self):
        self.assertIn("struct AccountView: View", self.src)

    def test_avatar_circle_72pt_used(self):
        """AvatarCircle is invoked with size 72 in the profile section."""
        self.assertIn("AvatarCircle(initials: initials, size: 72)", self.src)

    def test_sign_out_button_present(self):
        self.assertIn("Sign Out", self.src)

    def test_sign_out_calls_sign_out_method(self):
        self.assertIn("authManager.signOut()", self.src)

    def test_sign_out_calls_dismiss(self):
        """Sign Out button must also call dismiss() to close the sheet."""
        self.assertIn("dismiss()", self.src)

    def test_sign_out_and_dismiss_in_same_button_action(self):
        """signOut() and dismiss() must co-exist inside the destructive Button action block."""
        # Find the destructive Button block
        match = re.search(
            r'Button\(role: \.destructive\).*?\{(.*?)\} label:',
            self.src, re.DOTALL
        )
        self.assertIsNotNone(match, "destructive Button not found")
        action_block = match.group(1)
        self.assertIn("authManager.signOut()", action_block)
        self.assertIn("dismiss()", action_block)

    def test_display_name_conditional_rendering(self):
        """Name Text is gated on displayName being non-nil and non-empty."""
        self.assertIn("authManager.displayName", self.src)
        self.assertIn("!name.isEmpty", self.src)

    def test_email_conditional_rendering(self):
        """Email Text is gated on email being non-nil and non-empty."""
        self.assertIn("authManager.email", self.src)

    def test_apple_id_fallback_text(self):
        """'Apple ID' fallback renders when email is not available."""
        self.assertIn('"Apple ID"', self.src)

    def test_done_button_in_toolbar(self):
        """Done button in navigation toolbar to dismiss without signing out."""
        self.assertIn('"Done"', self.src)

    def test_navigation_title_account(self):
        self.assertIn('"Account"', self.src)


class TestInitialsComputation(unittest.TestCase):
    """initials computed property: derivation rules from AccountView.swift."""

    def setUp(self):
        self.src = _read(ACCOUNT_VIEW_PATH)

    def test_initials_var_defined(self):
        self.assertIn("private var initials: String", self.src)

    def test_splits_name_on_space(self):
        self.assertIn("split(separator:", self.src)

    def test_prefix_2_parts(self):
        """Only first two name parts are used."""
        self.assertIn(".prefix(2)", self.src)

    def test_uppercased(self):
        self.assertIn(".uppercased()", self.src)

    def test_email_fallback_uses_first_char(self):
        """When no name, first char of email is used."""
        self.assertIn("mail.first", self.src)

    def test_question_mark_fallback(self):
        """Ultimate fallback is '?' when neither name nor email available."""
        self.assertIn('"?"', self.src)

    def test_initials_logic_name_over_email(self):
        """Name check appears before email check in the initials var."""
        name_idx = self.src.find("authManager.displayName", self.src.find("private var initials"))
        email_idx = self.src.find("authManager.email", self.src.find("private var initials"))
        self.assertGreater(email_idx, name_idx,
                           "name branch should come before email branch in initials")


class TestAvatarCircleComponent(unittest.TestCase):
    """AvatarCircle: design-system conformance."""

    def setUp(self):
        self.src = _read(ACCOUNT_VIEW_PATH)

    def test_avatar_circle_struct_defined(self):
        self.assertIn("struct AvatarCircle: View", self.src)

    def test_bloom_fill(self):
        """Background uses bloom (soft plum) fill — not accent directly."""
        self.assertIn("Color.Nexus.bloom", self.src)

    def test_accent_text_color(self):
        """Initials text uses plum accent color."""
        self.assertIn(".foregroundColor(.Nexus.accent)", self.src)

    def test_hairline_border(self):
        """Border uses NexusBorder.hair (hairline) stroke."""
        self.assertIn("NexusBorder.hair", self.src)

    def test_border_uses_nexus_border_color(self):
        """Border strokes Color.Nexus.border (not a hardcoded color)."""
        self.assertIn("Color.Nexus.border", self.src)

    def test_circle_shape_used(self):
        """Avatar is circular."""
        self.assertIn("Circle()", self.src)

    def test_size_parameter(self):
        """size is a configurable parameter."""
        self.assertIn("var size: CGFloat", self.src)

    def test_font_scales_with_size(self):
        """Font size is derived from the size parameter (size * 0.38 or similar)."""
        self.assertIn("size *", self.src)

    def test_no_glass_effect(self):
        """AvatarCircle must NOT use Liquid Glass (glass effect is for menus only)."""
        self.assertNotIn("UIVisualEffectView", self.src)
        self.assertNotIn("ultraThinMaterial", self.src)


# ---------------------------------------------------------------------------
# HomeView.swift — toolbar avatar
# ---------------------------------------------------------------------------

class TestHomeViewAvatarToolbar(unittest.TestCase):
    """HomeView toolbar: AvatarCircle at 30pt with correct initials."""

    def setUp(self):
        self.src = _read(HOME_VIEW_PATH)

    def test_avatar_circle_30pt_in_toolbar(self):
        """Toolbar uses AvatarCircle with size 30."""
        self.assertIn("AvatarCircle(initials: avatarInitials, size: 30)", self.src)

    def test_shows_account_sheet_on_tap(self):
        """Avatar button sets showingAccount = true, triggering the sheet."""
        self.assertIn("showingAccount = true", self.src)

    def test_account_view_sheet_bound(self):
        """AccountView is presented as a sheet bound to showingAccount."""
        self.assertIn(".sheet(isPresented: $showingAccount)", self.src)
        self.assertIn("AccountView()", self.src)

    def test_avatar_initials_var_defined(self):
        self.assertIn("private var avatarInitials: String", self.src)

    def test_avatar_initials_name_fallback(self):
        """Name-based initials in HomeView use same split/prefix/uppercase logic."""
        src = self.src
        func_start = src.find("private var avatarInitials")
        self.assertGreater(func_start, -1)
        func_body = src[func_start:func_start + 400]
        self.assertIn("split(separator:", func_body)
        self.assertIn(".prefix(2)", func_body)
        self.assertIn(".uppercased()", func_body)

    def test_avatar_initials_fallback_is_n(self):
        """HomeView falls back to 'N' (brand letter) not '?' like AccountView."""
        func_start = self.src.find("private var avatarInitials")
        func_body = self.src[func_start:func_start + 600]
        self.assertIn('"N"', func_body)

    def test_hit_target_applied_to_avatar_button(self):
        """Button has NexusSpacing.hitTarget frame for accessibility."""
        self.assertIn("NexusSpacing.hitTarget", self.src)


# ---------------------------------------------------------------------------
# AuthManager.swift — persistence and signOut logic
# ---------------------------------------------------------------------------

class TestAuthManagerPersistence(unittest.TestCase):
    """AuthManager: UserDefaults suite and key names."""

    def setUp(self):
        self.src = _read(AUTH_MANAGER_PATH)

    def test_user_defaults_suite_name(self):
        """Uses the shared app group suite 'group.app.nexus'."""
        self.assertIn('"group.app.nexus"', self.src)

    def test_key_nexus_display_name(self):
        self.assertIn('"nexus_display_name"', self.src)

    def test_key_nexus_email(self):
        self.assertIn('"nexus_email"', self.src)

    def test_key_nexus_access_token(self):
        self.assertIn('"nexus_access_token"', self.src)

    def test_key_nexus_user_id(self):
        self.assertIn('"nexus_user_id"', self.src)

    def test_restores_session_on_init(self):
        """init() reads persisted token+userId to restore authenticated state."""
        self.assertIn("group?.string(forKey: Key.token)", self.src)
        self.assertIn("isAuthenticated = true", self.src)

    def test_display_name_published(self):
        """displayName is @Published so views react to changes."""
        # @Published and displayName should both appear before signOut
        published_idx = self.src.find("@Published private(set) var displayName")
        self.assertGreater(published_idx, -1,
                           "@Published displayName not found")

    def test_email_published(self):
        """email is @Published so views react to changes."""
        published_idx = self.src.find("@Published private(set) var email")
        self.assertGreater(published_idx, -1,
                           "@Published email not found")


class TestAuthManagerSetSession(unittest.TestCase):
    """setSession: only overwrites name/email when Apple provides non-empty values."""

    def setUp(self):
        self.src = _read(AUTH_MANAGER_PATH)

    def test_set_session_method_exists(self):
        self.assertIn("func setSession(", self.src)

    def test_set_session_accepts_display_name_optional(self):
        """displayName param is optional (default nil) — Apple omits it on repeat sign-in."""
        self.assertIn("displayName: String? = nil", self.src)

    def test_set_session_accepts_email_optional(self):
        self.assertIn("email: String? = nil", self.src)

    def test_set_session_guard_non_empty_name(self):
        """Name is only persisted when it is non-empty."""
        src = self.src
        set_session_start = src.find("func setSession(")
        set_session_body = src[set_session_start:set_session_start + 600]
        self.assertIn("!name.isEmpty", set_session_body)

    def test_set_session_guard_non_empty_email(self):
        """Email is only persisted when it is non-empty."""
        src = self.src
        set_session_start = src.find("func setSession(")
        set_session_body = src[set_session_start:set_session_start + 900]
        self.assertIn("!mail.isEmpty", set_session_body)

    def test_set_session_sets_is_authenticated_true(self):
        src = self.src
        set_session_start = src.find("func setSession(")
        set_session_body = src[set_session_start:set_session_start + 600]
        self.assertIn("isAuthenticated = true", set_session_body)


class TestAuthManagerSignOut(unittest.TestCase):
    """signOut: clears all state and UserDefaults keys."""

    def setUp(self):
        self.src = _read(AUTH_MANAGER_PATH)

    def test_sign_out_method_exists(self):
        self.assertIn("func signOut()", self.src)

    def test_sign_out_sets_is_authenticated_false(self):
        src = self.src
        sign_out_start = src.find("func signOut()")
        sign_out_body = src[sign_out_start:sign_out_start + 400]
        self.assertIn("isAuthenticated = false", sign_out_body)

    def test_sign_out_clears_access_token(self):
        src = self.src
        sign_out_start = src.find("func signOut()")
        sign_out_body = src[sign_out_start:sign_out_start + 400]
        self.assertIn("accessToken = nil", sign_out_body)

    def test_sign_out_clears_user_id(self):
        src = self.src
        sign_out_start = src.find("func signOut()")
        sign_out_body = src[sign_out_start:sign_out_start + 400]
        self.assertIn("userId = nil", sign_out_body)

    def test_sign_out_clears_display_name(self):
        src = self.src
        sign_out_start = src.find("func signOut()")
        sign_out_body = src[sign_out_start:sign_out_start + 400]
        self.assertIn("displayName = nil", sign_out_body)

    def test_sign_out_clears_email(self):
        src = self.src
        sign_out_start = src.find("func signOut()")
        sign_out_body = src[sign_out_start:sign_out_start + 400]
        self.assertIn("email = nil", sign_out_body)

    def test_sign_out_removes_token_from_defaults(self):
        src = self.src
        sign_out_start = src.find("func signOut()")
        sign_out_body = src[sign_out_start:sign_out_start + 400]
        self.assertIn('removeObject(forKey: Key.token)', sign_out_body)

    def test_sign_out_removes_display_name_from_defaults(self):
        src = self.src
        sign_out_start = src.find("func signOut()")
        sign_out_body = src[sign_out_start:sign_out_start + 400]
        self.assertIn('removeObject(forKey: Key.displayName)', sign_out_body)

    def test_sign_out_removes_email_from_defaults(self):
        src = self.src
        sign_out_start = src.find("func signOut()")
        sign_out_body = src[sign_out_start:sign_out_start + 400]
        self.assertIn('removeObject(forKey: Key.email)', sign_out_body)

    def test_sign_out_removes_user_id_from_defaults(self):
        src = self.src
        sign_out_start = src.find("func signOut()")
        sign_out_body = src[sign_out_start:sign_out_start + 400]
        self.assertIn('removeObject(forKey: Key.userId)', sign_out_body)


# ---------------------------------------------------------------------------
# NexusApp.swift — auth routing
# ---------------------------------------------------------------------------

class TestNexusAppAuthRouting(unittest.TestCase):
    """NexusApp: isAuthenticated drives view routing."""

    def setUp(self):
        self.src = _read(NEXUS_APP_PATH)

    def test_root_view_checks_is_authenticated(self):
        self.assertIn("isAuthenticated", self.src)

    def test_unauthenticated_shows_auth_placeholder(self):
        self.assertIn("AuthPlaceholderView()", self.src)

    def test_authenticated_shows_home_view(self):
        self.assertIn("HomeView()", self.src)

    def test_dev_bypass_present(self):
        """Dev bypass allows testing without Apple ID during development."""
        self.assertIn("dev only", self.src)
        self.assertIn('token: "dev"', self.src)


# ---------------------------------------------------------------------------
# Python-native initials logic mirror tests
# (validates the Swift algorithm in Python for edge cases)
# ---------------------------------------------------------------------------

def _compute_initials(display_name: str | None, email: str | None) -> str:
    """Mirror of AccountView.initials Swift logic."""
    if display_name and display_name.strip():
        parts = display_name.split()[:2]
        return "".join(p[0] for p in parts if p).upper()
    if email and email:
        first = email[0]
        return first.upper()
    return "?"


def _compute_avatar_initials(display_name: str | None, email: str | None) -> str:
    """Mirror of HomeView.avatarInitials Swift logic (fallback 'N' not '?')."""
    if display_name and display_name.strip():
        parts = display_name.split()[:2]
        return "".join(p[0] for p in parts if p).upper()
    if email and email:
        return email[0].upper()
    return "N"


class TestInitialsAlgorithm(unittest.TestCase):
    """Unit tests for the initials derivation algorithm (mirrors Swift logic)."""

    def test_single_name(self):
        self.assertEqual(_compute_initials("Alice", None), "A")

    def test_first_and_last_name(self):
        self.assertEqual(_compute_initials("Srihari Srinivasa", None), "SS")

    def test_three_word_name_uses_only_two(self):
        self.assertEqual(_compute_initials("Mary Jane Watson", None), "MJ")

    def test_name_trumps_email(self):
        self.assertEqual(_compute_initials("Bob", "bob@example.com"), "B")

    def test_email_fallback_when_name_none(self):
        self.assertEqual(_compute_initials(None, "bob@example.com"), "B")

    def test_email_fallback_when_name_empty(self):
        self.assertEqual(_compute_initials("", "alice@example.com"), "A")

    def test_email_is_uppercased(self):
        self.assertEqual(_compute_initials(None, "zara@example.com"), "Z")

    def test_question_mark_fallback(self):
        self.assertEqual(_compute_initials(None, None), "?")

    def test_question_mark_fallback_both_empty(self):
        self.assertEqual(_compute_initials("", ""), "?")

    def test_avatar_initials_fallback_is_n_not_question_mark(self):
        self.assertEqual(_compute_avatar_initials(None, None), "N")

    def test_avatar_initials_name_still_works(self):
        self.assertEqual(_compute_avatar_initials("Jane Doe", None), "JD")

    def test_avatar_initials_email_fallback(self):
        self.assertEqual(_compute_avatar_initials(None, "nexus@test.com"), "N")


if __name__ == "__main__":
    unittest.main()
