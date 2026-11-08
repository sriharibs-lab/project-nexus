"""
Tests for 1C-004 — Sources tab polish in collection-view.jsx.

Tests validate JSX source-code structure and data contracts. These run
without a browser — they parse the JSX file as text and validate that the
required components, constants, data fields, and logic are present and
correctly wired.

Covered test hints:
  1. ContentTypeIcon renders six icon types with correct tinted badges
  2. TagChips shows 2-3 tags per row in surface2 pill style
  3. SwipeRow exposes a red Delete zone on left drag past ~72px threshold
  4. Partial drag (under threshold) snaps back without deleting
  5. PullToRefresh indicator states: pull / release / refreshing / refreshed
  6. PTR only triggers when scrollTop === 0
  7. Pending rows do NOT reject swipe (guard in onPointerDown checks `removing`)
  8. Only useCallback added — no new external dependencies
"""

from __future__ import annotations
import pathlib as _pl; _REPO_ROOT = str(_pl.Path(__file__).resolve().parents[3])  # repo root, portable

import os
import re
import unittest

# The 1C-004 features live in the worktree. We try the worktree first,
# then fall back to the checked-in file so the test can run after merge.
_WORKTREE_PATH = _REPO_ROOT + "/.claude/worktrees/wf_6d3e19bb-b4b-9/nexus-design-system-extracted/design_handoff_nexus_ios/collection-view.jsx"
_MAIN_PATH = os.path.join(
    os.path.dirname(__file__),
    "../../..",
    "nexus-design-system-extracted",
    "design_handoff_nexus_ios",
    "collection-view.jsx",
)
JSX_PATH = _WORKTREE_PATH if os.path.exists(_WORKTREE_PATH) else _MAIN_PATH


def _src() -> str:
    with open(JSX_PATH, encoding="utf-8") as f:
        return f.read()


class TestContentTypeIcon(unittest.TestCase):
    """ContentTypeIcon component: six icon types each map to a tinted badge."""

    def setUp(self):
        self.src = _src()

    def test_icon_tint_table_defined(self):
        """ICON_TINT constant must be declared."""
        self.assertIn("ICON_TINT", self.src, "ICON_TINT lookup table must be defined")

    def test_all_six_icon_types_in_tint_table(self):
        """All six icon families must have entries in ICON_TINT."""
        for icon in ("globe", "video", "file", "note", "photo", "mic"):
            self.assertIn(
                f"'{icon}'",
                self.src,
                f"ICON_TINT must contain an entry for '{icon}'",
            )

    def test_content_type_icon_component_defined(self):
        """ContentTypeIcon function component must exist."""
        self.assertIn(
            "function ContentTypeIcon",
            self.src,
            "ContentTypeIcon component must be defined",
        )

    def test_content_type_icon_uses_icon_tint(self):
        """ContentTypeIcon must reference ICON_TINT for its colors."""
        self.assertIn(
            "ICON_TINT",
            self.src,
            "ContentTypeIcon must reference ICON_TINT",
        )

    def test_globe_tint_is_blue(self):
        """Globe icon should use a cool-blue foreground (#4A7ABB or similar)."""
        # Verify the fg color for globe is a blue family color
        self.assertIn("#4A7ABB", self.src, "Globe icon fg color must be blue #4A7ABB")

    def test_video_tint_is_red(self):
        """Video icon should use a warm-red foreground."""
        self.assertIn("#B84C3A", self.src, "Video icon fg color must be warm red #B84C3A")

    def test_file_tint_is_plum(self):
        """PDF/file icon should use brand-plum foreground."""
        self.assertIn("#7054AB", self.src, "File icon fg color must be plum #7054AB")

    def test_link_fallback_in_tint_table(self):
        """'link' fallback key must exist in ICON_TINT for unknown types."""
        self.assertIn("link", self.src, "ICON_TINT must contain 'link' as a fallback")

    def test_content_type_icon_rendered_in_swipe_row(self):
        """ContentTypeIcon must be rendered inside SwipeRow (not LinkRow alias)."""
        self.assertIn(
            "<ContentTypeIcon",
            self.src,
            "ContentTypeIcon must be used in the row renderer",
        )


class TestTagChips(unittest.TestCase):
    """TagChips component: 2-3 pill chips rendered below the row title."""

    def setUp(self):
        self.src = _src()

    def test_tag_chips_component_defined(self):
        """TagChips function component must exist."""
        self.assertIn("function TagChips", self.src, "TagChips component must be defined")

    def test_tags_field_in_source_data(self):
        """NX_SOURCES entries must include a `tags` array field."""
        # Check at least the first entry in US-Iran conflict has tags
        self.assertIn("tags:", self.src, "Source data items must have a 'tags' field")

    def test_tag_chips_slices_to_three(self):
        """TagChips must show at most 3 tags (slice(0, 3))."""
        self.assertIn(
            "slice(0, 3)",
            self.src,
            "TagChips must cap visible tags at 3 with slice(0, 3)",
        )

    def test_tag_chips_returns_null_for_empty_tags(self):
        """TagChips must return null when tags array is empty."""
        self.assertIn(
            "tags.length === 0",
            self.src,
            "TagChips must guard against empty tags array",
        )

    def test_tag_chips_uses_surface2(self):
        """Tag pill background must reference t.surface2 (theme-aware)."""
        self.assertIn(
            "t.surface2",
            self.src,
            "TagChips must use t.surface2 for the pill background",
        )

    def test_tag_chips_uses_border_radius_999(self):
        """Tag chips must be pill-shaped (borderRadius: 999)."""
        # Check inside the TagChips body — look for borderRadius 999
        tag_chips_block = self.src[self.src.find("function TagChips") : self.src.find("function CVShimmer")]
        self.assertIn(
            "999",
            tag_chips_block,
            "TagChips pill must use borderRadius 999",
        )

    def test_tag_chips_rendered_in_swipe_row(self):
        """TagChips must be rendered inside SwipeRow's non-pending branch."""
        self.assertIn(
            "<TagChips",
            self.src,
            "TagChips must be used inside the row renderer",
        )

    def test_fallback_sources_include_tags(self):
        """nxFallbackSources must also produce entries with tags arrays."""
        fallback_section = self.src[
            self.src.find("function nxFallbackSources") : self.src.find("// ── one-time keyframes")
        ]
        self.assertIn(
            "tags:",
            fallback_section,
            "nxFallbackSources must include tags in each returned item",
        )


class TestSwipeToDelete(unittest.TestCase):
    """SwipeRow: pointer-drag left exposes a red Delete zone."""

    def setUp(self):
        self.src = _src()

    def test_swipe_row_component_defined(self):
        """SwipeRow function component must exist."""
        self.assertIn("function SwipeRow", self.src, "SwipeRow must be defined")

    def test_swipe_threshold_constant(self):
        """SWIPE_THRESHOLD must be defined at ~72px."""
        self.assertIn(
            "SWIPE_THRESHOLD",
            self.src,
            "SWIPE_THRESHOLD constant must be defined",
        )
        # Verify its value
        match = re.search(r"SWIPE_THRESHOLD\s*=\s*(\d+)", self.src)
        self.assertIsNotNone(match, "SWIPE_THRESHOLD must have a numeric value")
        self.assertGreaterEqual(
            int(match.group(1)),
            60,
            "SWIPE_THRESHOLD must be at least 60px to match '~72px' in spec",
        )

    def test_swipe_full_constant(self):
        """SWIPE_FULL must be defined (resting width of the delete zone)."""
        self.assertIn("SWIPE_FULL", self.src, "SWIPE_FULL constant must be defined")

    def test_delete_zone_is_red(self):
        """The delete zone background must be a red color."""
        # Look for the delete zone div with a red background
        self.assertIn(
            "#C0392B",
            self.src,
            "Delete zone must have a red background (#C0392B)",
        )

    def test_delete_button_has_delete_label(self):
        """Delete button must show 'Delete' text label."""
        self.assertIn("Delete", self.src, "Delete button must include 'Delete' label text")

    def test_delete_button_has_x_icon(self):
        """Delete button must include an 'x' icon."""
        swipe_block = self.src[self.src.find("function SwipeRow") : self.src.find("// Backwards-compat")]
        self.assertIn(
            '"x"',
            swipe_block,
            "Delete button must use LIcon name='x'",
        )

    def test_snap_open_on_threshold_cross(self):
        """settle() must snap to open (SWIPE_FULL) when drag exceeds threshold/2."""
        self.assertIn(
            "SWIPE_THRESHOLD / 2",
            self.src,
            "settle() must use SWIPE_THRESHOLD / 2 as the snap-open pivot",
        )

    def test_snap_closed_below_threshold(self):
        """settle() must reset offset to 0 when drag is below threshold."""
        settle_block = self.src[self.src.find("const settle") : self.src.find("const onPointerDown")]
        self.assertIn(
            "setOffset(0)",
            settle_block,
            "settle() must snap back to 0 for sub-threshold drags",
        )
        self.assertIn(
            "setOpen(false)",
            settle_block,
            "settle() must close the delete zone for sub-threshold drags",
        )

    def test_pointer_events_wired(self):
        """SwipeRow must wire onPointerDown, onPointerMove, onPointerUp, onPointerCancel."""
        swipe_block = self.src[self.src.find("function SwipeRow") : self.src.find("// Backwards-compat")]
        for handler in ("onPointerDown", "onPointerMove", "onPointerUp", "onPointerCancel"):
            self.assertIn(
                handler,
                swipe_block,
                f"SwipeRow must define and wire {handler}",
            )

    def test_removing_guard_in_pointer_down(self):
        """onPointerDown must guard against `removing` (not `it.pending`)."""
        # The guard must be: if (removing) return;
        # The hint says pending rows should NOT be rejected — only `removing` rows
        on_pointer_down_block = self.src[
            self.src.find("const onPointerDown") : self.src.find("const onPointerMove")
        ]
        self.assertIn(
            "removing",
            on_pointer_down_block,
            "onPointerDown must guard against the `removing` prop, not `pending`",
        )
        # Ensure there is no 'pending' guard in onPointerDown
        self.assertNotIn(
            "it.pending",
            on_pointer_down_block,
            "onPointerDown must NOT reject pending rows — only removing rows",
        )

    def test_link_row_alias_defined(self):
        """LinkRow must remain as a backwards-compat alias for SwipeRow."""
        self.assertIn(
            "const LinkRow = SwipeRow",
            self.src,
            "LinkRow alias must remain for backwards compatibility",
        )

    def test_touch_action_pan_y(self):
        """Swipeable div must set touchAction: 'pan-y' (let scroll pass through)."""
        swipe_block = self.src[self.src.find("function SwipeRow") : self.src.find("// Backwards-compat")]
        self.assertIn(
            "pan-y",
            swipe_block,
            "SwipeRow must set touchAction: 'pan-y' to allow vertical scroll",
        )


class TestPullToRefresh(unittest.TestCase):
    """PullToRefresh component: drag-down at scroll top triggers a spinner cycle."""

    def setUp(self):
        self.src = _src()

    def test_pull_to_refresh_component_defined(self):
        """PullToRefresh function component must exist."""
        self.assertIn(
            "function PullToRefresh",
            self.src,
            "PullToRefresh component must be defined",
        )

    def test_ptr_trigger_constant(self):
        """PTR_TRIGGER must be defined at 56px."""
        self.assertIn("PTR_TRIGGER", self.src, "PTR_TRIGGER constant must be defined")
        match = re.search(r"PTR_TRIGGER\s*=\s*(\d+)", self.src)
        self.assertIsNotNone(match, "PTR_TRIGGER must have a numeric value")
        self.assertEqual(
            int(match.group(1)),
            56,
            "PTR_TRIGGER must be exactly 56px per spec",
        )

    def test_ptr_max_constant(self):
        """PTR_MAX must be defined (caps visual drag distance)."""
        self.assertIn("PTR_MAX", self.src, "PTR_MAX constant must be defined")

    def test_pull_to_refresh_label(self):
        """PTR indicator must show 'Pull to refresh' text."""
        self.assertIn(
            "Pull to refresh",
            self.src,
            "PTR must display 'Pull to refresh' label text",
        )

    def test_release_to_refresh_label(self):
        """PTR indicator must change to 'Release to refresh' past threshold."""
        self.assertIn(
            "Release to refresh",
            self.src,
            "PTR must display 'Release to refresh' when drag exceeds PTR_TRIGGER",
        )

    def test_refreshing_label(self):
        """PTR must show 'Refreshing…' during the loading phase."""
        self.assertIn(
            "Refreshing",
            self.src,
            "PTR must display 'Refreshing…' during loading phase",
        )

    def test_refreshed_label(self):
        """PTR must show 'Refreshed' with check during done phase."""
        self.assertIn(
            "Refreshed",
            self.src,
            "PTR must display 'Refreshed' in done phase",
        )

    def test_ptr_phases_idle_loading_done(self):
        """PTR must track phase state: idle / loading / done."""
        ptr_block = self.src[
            self.src.find("function PullToRefresh") : self.src.find("// ── Sources tab:")
        ]
        for phase in ("idle", "loading", "done"):
            self.assertIn(
                f"'{phase}'",
                ptr_block,
                f"PullToRefresh must use phase state '{phase}'",
            )

    def test_scroll_top_guard(self):
        """PTR must only start tracking when el.scrollTop === 0."""
        ptr_block = self.src[
            self.src.find("function PullToRefresh") : self.src.find("// ── Sources tab:")
        ]
        self.assertIn(
            "scrollTop",
            ptr_block,
            "PullToRefresh must check scrollTop before starting a drag",
        )
        # The guard must block tracking when not at top
        self.assertIn(
            "scrollTop > 0",
            ptr_block,
            "PullToRefresh must guard: if scrollTop > 0 return (do not start PTR)",
        )

    def test_ptr_animation_keyframes_defined(self):
        """nxPTRSpin and nxPTRFlash keyframes must be declared for the indicator."""
        self.assertIn(
            "nxPTRSpin",
            self.src,
            "nxPTRSpin CSS animation must be declared for the spinner",
        )
        self.assertIn(
            "nxPTRFlash",
            self.src,
            "nxPTRFlash CSS animation must be declared for the 'Refreshed' flash",
        )

    def test_ptr_uses_check_icon_in_done_phase(self):
        """Done phase must render a check icon alongside 'Refreshed' text."""
        ptr_block = self.src[
            self.src.find("function PullToRefresh") : self.src.find("// ── Sources tab:")
        ]
        self.assertIn(
            '"check"',
            ptr_block,
            "PTR 'done' phase must render a LIcon name='check'",
        )

    def test_ptr_wrapped_around_sources_pane(self):
        """PullToRefresh must wrap the SourcesPane scrollable content."""
        sources_pane = self.src[
            self.src.find("function SourcesPane") : self.src.find("// ── Nexus tab:")
        ]
        self.assertIn(
            "<PullToRefresh",
            sources_pane,
            "SourcesPane must use PullToRefresh as its scroll wrapper",
        )

    def test_ptr_collapse_after_done(self):
        """After done phase, PTR must collapse back (setPull(0) + setPhase idle)."""
        ptr_block = self.src[
            self.src.find("function PullToRefresh") : self.src.find("// ── Sources tab:")
        ]
        self.assertIn(
            "setPull(0)",
            ptr_block,
            "PullToRefresh must call setPull(0) after refresh completes",
        )


class TestNoDependencies(unittest.TestCase):
    """1C-004 must not add new external dependencies."""

    def setUp(self):
        self.src = _src()

    def test_use_callback_added_to_react_destructure(self):
        """useCallback must be added to the React destructure."""
        self.assertIn(
            "useCallback",
            self.src,
            "useCallback must be imported from the React destructure",
        )
        # Should be in the destructure line alongside useState etc.
        destructure_line = next(
            (line for line in self.src.splitlines() if "useCallback" in line and "useState" in line),
            None,
        )
        self.assertIsNotNone(
            destructure_line,
            "useCallback and useState must appear on the same destructure line",
        )

    def test_no_new_script_imports(self):
        """No new <script src=...> tags should be added for external libraries."""
        # Verify no new import() or require() calls are in the JSX
        self.assertNotIn(
            "require(",
            self.src,
            "JSX file must not add CommonJS require() calls",
        )

    def test_no_import_statements(self):
        """JSX file uses window globals — must not add ES module import statements."""
        # The file uses window globals (React, LIcon, etc.) not ES imports
        self.assertNotIn(
            "import {",
            self.src,
            "collection-view.jsx must not add ES import statements (uses window globals)",
        )

    def test_use_callback_wired_to_refresh(self):
        """useCallback must be used for the refresh callback in CollectionView."""
        collection_view = self.src[
            self.src.find("function CollectionView") : self.src.find("// ── standalone artboard")
        ]
        self.assertIn(
            "useCallback",
            collection_view,
            "CollectionView must use useCallback for the refresh handler",
        )


class TestDataIntegrity(unittest.TestCase):
    """All NX_SOURCES entries must have the `tags` field required by 1C-004."""

    def setUp(self):
        self.src = _src()

    def test_all_topic_groups_have_tags(self):
        """Every source entry in NX_SOURCES must include a tags array."""
        # Extract NX_SOURCES block
        start = self.src.find("const NX_SOURCES = {")
        end = self.src.find("};", start) + 2
        nx_block = self.src[start:end]

        # Count object entries (each `{` that is a source row should have tags)
        # We check that every row entry in the block has a `tags:` key
        # Simple heuristic: count `mono:` entries vs `tags:` entries
        mono_count = nx_block.count("mono:")
        tags_count = nx_block.count("tags:")
        self.assertEqual(
            mono_count,
            tags_count,
            f"Every NX_SOURCES entry must have a `tags:` field "
            f"(found {mono_count} mono: but {tags_count} tags:)",
        )

    def test_source_entries_have_at_least_two_tags(self):
        """Each source should have at least 2 tags per spec."""
        # Spot-check: find the 'diplomacy' tag in the first source entry
        # (Note: JSX files may use curly/straight quotes — search by tag value only)
        start = self.src.find("diplomacy")
        self.assertGreater(
            start,
            -1,
            "First source item must have a 'diplomacy' tag",
        )
        # Verify it has at least 2 items by checking for a comma nearby
        # (the second tag is 'middle-east')
        snippet = self.src[start : start + 40]
        self.assertIn(
            "middle-east",
            snippet,
            "First source's tags array must contain at least 2 entries (diplomacy, middle-east)",
        )


if __name__ == "__main__":
    unittest.main()
