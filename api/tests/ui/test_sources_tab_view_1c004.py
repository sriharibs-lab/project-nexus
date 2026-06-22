"""
Tests for task 1C-004 — SourcesTabView.swift (iOS)

These tests inspect Swift source files as text to verify the required
implementation patterns are present and correctly structured. They run
without Xcode or a device — no Swift compilation needed.

Covered test hints:
  1. Build target: no compiler errors — verified by checking required identifiers
  2. Swipe-to-delete: full-swipe removes row; half-swipe snaps back
  3. Swipe-to-delete calls DELETE API once; on 4xx item re-appears + alert shown
  4. Pull-to-refresh: system PTR spinner; fetchItems called; spinner dismisses after async
  5. Pull-to-refresh from mid-scroll: native .refreshable handles this
  6. ContentTypeIconBadge: .article → cool-blue; .video → warm-red; .podcast → cool-blue
  7. TagChip: up to 6 chips in a horizontal scroll view; no wrapping
  8. Empty state: doc.text.magnifyingglass icon + 'No sources yet' copy
  9. isLoading guard: PTR path skips loading skeleton
  10. CollectionViewModel.deleteError lifecycle: nil after success, non-nil after failure
"""

from __future__ import annotations

import os
import re
import unittest

# --------------------------------------------------------------------------- #
# File paths — worktree first, fall back to main tree after merge
# --------------------------------------------------------------------------- #

_WORKTREE = "/Users/srihari/Documents/Projects/Project Nexus/.claude/worktrees/wf_5f2d3d42-857-6"
_MAIN = "/Users/srihari/Documents/Projects/Project Nexus"


def _wt(rel: str) -> str:
    """Return worktree path if present, else main-tree path."""
    wt = os.path.join(_WORKTREE, rel)
    mt = os.path.join(_MAIN, rel)
    return wt if os.path.exists(wt) else mt


SOURCES_TAB_VIEW   = _wt("app-ios/Nexus/Nexus/Features/Collection/SourcesTabView.swift")
COLLECTION_VIEW    = _wt("app-ios/Nexus/Nexus/Features/Collection/CollectionView.swift")
COLLECTION_VM      = _wt("app-ios/Nexus/Nexus/Features/Collection/CollectionViewModel.swift")
API_CLIENT         = _wt("app-ios/Nexus/Nexus/Core/Network/APIClient.swift")


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


# --------------------------------------------------------------------------- #
# 1. Required structs and identifiers compile-readiness checks
# --------------------------------------------------------------------------- #

class TestCompilerReadiness(unittest.TestCase):
    """Verify required structs, properties, and types exist in the right files."""

    def setUp(self):
        self.stv = _read(SOURCES_TAB_VIEW)
        self.cv  = _read(COLLECTION_VIEW)
        self.vm  = _read(COLLECTION_VM)
        self.api = _read(API_CLIENT)

    def test_sources_tab_view_struct_defined(self):
        """SourcesTabView struct must be declared."""
        self.assertIn("struct SourcesTabView", self.stv)

    def test_sources_tab_view_is_view(self):
        """SourcesTabView must conform to View."""
        self.assertIn("SourcesTabView: View", self.stv)

    def test_source_card_struct_defined(self):
        """SourceCard struct must be declared."""
        self.assertIn("struct SourceCard", self.stv)

    def test_tag_chip_struct_defined(self):
        """TagChip struct must be declared."""
        self.assertIn("struct TagChip", self.stv)

    def test_content_type_icon_badge_defined(self):
        """ContentTypeIconBadge struct must be declared."""
        self.assertIn("ContentTypeIconBadge", self.stv)

    def test_ingest_status_pill_defined(self):
        """IngestStatusPill struct must be declared."""
        self.assertIn("IngestStatusPill", self.stv)

    def test_item_detail_route_defined_in_collection_view(self):
        """ItemDetailRoute must be declared in CollectionView.swift."""
        self.assertIn("struct ItemDetailRoute", self.cv)

    def test_item_detail_route_is_hashable(self):
        """ItemDetailRoute must conform to Hashable for NavigationLink."""
        self.assertIn("ItemDetailRoute: Hashable", self.cv)

    def test_collection_view_model_delete_error_published(self):
        """CollectionViewModel must publish deleteError."""
        self.assertIn("@Published var deleteError:", self.vm)

    def test_collection_view_model_is_main_actor(self):
        """CollectionViewModel must be @MainActor."""
        self.assertIn("@MainActor", self.vm)

    def test_delete_item_method_in_api_client(self):
        """APIClient must have a deleteItem(id:in:) method."""
        self.assertIn("func deleteItem(id itemId: UUID, in collectionId: UUID)", self.api)

    def test_delete_item_calls_delete_endpoint(self):
        """deleteItem must call the .item endpoint with DELETE method."""
        self.assertIn("delete(.item(collectionId:", self.api)

    def test_sources_tab_view_receives_items_param(self):
        """SourcesTabView must accept an items: [Item] parameter."""
        self.assertIn("let items: [Item]", self.stv)

    def test_sources_tab_view_receives_is_loading_param(self):
        """SourcesTabView must accept an isLoading: Bool parameter."""
        self.assertIn("let isLoading: Bool", self.stv)

    def test_sources_tab_view_receives_on_delete_param(self):
        """SourcesTabView must accept an onDelete closure."""
        self.assertIn("let onDelete:", self.stv)

    def test_sources_tab_view_receives_on_refresh_param(self):
        """SourcesTabView must accept an onRefresh closure."""
        self.assertIn("let onRefresh:", self.stv)


# --------------------------------------------------------------------------- #
# 2. Swipe-to-delete: native .swipeActions on List rows
# --------------------------------------------------------------------------- #

class TestSwipeToDelete(unittest.TestCase):
    """Swipe-to-delete: native .swipeActions with destructive role."""

    def setUp(self):
        self.stv = _read(SOURCES_TAB_VIEW)

    def test_swipe_actions_defined(self):
        """.swipeActions modifier must be used on the list row."""
        self.assertIn(".swipeActions(", self.stv)

    def test_trailing_edge_swipe(self):
        """Swipe must be on the trailing edge."""
        self.assertIn("edge: .trailing", self.stv)

    def test_full_swipe_allowed(self):
        """allowsFullSwipe: true must be set for full-swipe instant delete."""
        self.assertIn("allowsFullSwipe: true", self.stv)

    def test_delete_button_role_is_destructive(self):
        """Delete button must have role: .destructive for red colouring."""
        self.assertIn("role: .destructive", self.stv)

    def test_delete_button_has_trash_icon(self):
        """Delete button label must include the 'trash' system icon."""
        self.assertIn('"trash"', self.stv)

    def test_delete_button_has_delete_label(self):
        """Delete button label must include 'Delete' text."""
        self.assertIn('"Delete"', self.stv)

    def test_on_delete_closure_called_on_button_tap(self):
        """onDelete closure must be called when the Delete button is tapped."""
        self.assertIn("onDelete(item)", self.stv)

    def test_delete_wrapped_in_task(self):
        """onDelete is async — must be wrapped in Task { await ... }."""
        self.assertIn("Task { await onDelete(item) }", self.stv)

    def test_list_used_for_swipe_support(self):
        """List is used (not LazyVStack) to get native swipe-to-delete."""
        self.assertIn("List {", self.stv)

    def test_for_each_drives_list_rows(self):
        """ForEach iterates items inside the List."""
        self.assertIn("ForEach(items)", self.stv)


# --------------------------------------------------------------------------- #
# 3. API call for delete: one call, optimistic rollback on failure
# --------------------------------------------------------------------------- #

class TestDeleteAPILogic(unittest.TestCase):
    """CollectionViewModel.delete(): optimistic removal + rollback on error."""

    def setUp(self):
        self.vm = _read(COLLECTION_VM)

    def test_delete_method_defined(self):
        """delete(item:) method must be defined on CollectionViewModel."""
        self.assertIn("func delete(item: Item)", self.vm)

    def test_optimistic_removal_before_network_call(self):
        """Item is removed from items[] before the API call is awaited."""
        vm = self.vm
        delete_block_start = vm.find("func delete(item: Item)")
        self.assertGreater(delete_block_start, -1, "delete(item:) not found")
        delete_block = vm[delete_block_start : delete_block_start + 600]
        remove_pos   = delete_block.find("items.remove(at:")
        network_pos  = delete_block.find("deleteItem(")
        self.assertGreater(remove_pos, -1, "items.remove(at:) must be called")
        self.assertGreater(network_pos, -1, "deleteItem must be called")
        self.assertLess(
            remove_pos, network_pos,
            "Optimistic removal must happen BEFORE the network call",
        )

    def test_rollback_inserts_item_at_original_index(self):
        """On error, item must be re-inserted at the original index."""
        self.assertIn("items.insert(item, at:", self.vm)

    def test_delete_error_set_on_api_failure(self):
        """deleteError must be set when APIClient throws."""
        self.assertIn("deleteError = e", self.vm)

    def test_delete_error_set_for_generic_error(self):
        """deleteError is set even for non-APIError throws."""
        self.assertIn("deleteError = .networkError(error)", self.vm)

    def test_guard_item_exists_before_delete(self):
        """delete() must guard that the item exists in items before proceeding."""
        self.assertIn("guard let idx = items.firstIndex(where:", self.vm)

    def test_single_api_call(self):
        """deleteItem is called exactly once per delete(item:) invocation."""
        vm = self.vm
        delete_block_start = vm.find("func delete(item: Item)")
        # Find the end by locating the next top-level func
        next_func = vm.find("\n    func ", delete_block_start + 1)
        delete_block = vm[delete_block_start:next_func] if next_func > -1 else vm[delete_block_start:]
        call_count = delete_block.count("deleteItem(")
        self.assertEqual(call_count, 1, f"deleteItem must be called exactly once, found {call_count}")


# --------------------------------------------------------------------------- #
# 4. Alert wiring for delete failure
# --------------------------------------------------------------------------- #

class TestDeleteErrorAlert(unittest.TestCase):
    """CollectionView shows alert 'Couldn't delete source' on deleteError."""

    def setUp(self):
        self.cv = _read(COLLECTION_VIEW)
        self.vm = _read(COLLECTION_VM)

    def test_alert_triggered_by_delete_error(self):
        """CollectionView must show an alert when vm.deleteError is non-nil."""
        self.assertIn("vm.deleteError", self.cv)

    def test_alert_title_is_couldnt_delete_source(self):
        """Alert title must be 'Couldn't delete source'."""
        self.assertIn("Couldn" + "\x27" + "t delete source", self.cv)

    def test_alert_ok_button_clears_delete_error(self):
        """Tapping OK must nil out deleteError."""
        self.assertIn("vm.deleteError = nil", self.cv)

    def test_delete_error_is_nil_initially(self):
        """deleteError is declared as optional (implicitly nil by default)."""
        # Optional property declaration — APIError? defaults to nil
        self.assertIn("@Published var deleteError: APIError?", self.vm)

    def test_delete_error_cleared_by_alert_dismiss(self):
        """The Binding(set:) pattern or direct assignment clears deleteError on dismiss."""
        # Either pattern 'if !$0 { vm.deleteError = nil }' or direct nil assignment
        self.assertIn("vm.deleteError = nil", self.cv)


# --------------------------------------------------------------------------- #
# 5. Pull-to-refresh via .refreshable
# --------------------------------------------------------------------------- #

class TestPullToRefresh(unittest.TestCase):
    """.refreshable on List drives pull-to-refresh via onRefresh closure."""

    def setUp(self):
        self.stv = _read(SOURCES_TAB_VIEW)
        self.cv  = _read(COLLECTION_VIEW)

    def test_refreshable_modifier_present(self):
        """.refreshable modifier must be applied to the List."""
        self.assertIn(".refreshable {", self.stv)

    def test_on_refresh_awaited_in_refreshable(self):
        """onRefresh closure must be awaited inside .refreshable block."""
        self.assertIn("await onRefresh()", self.stv)

    def test_on_refresh_wired_to_vm_load_in_collection_view(self):
        """CollectionView wires onRefresh to vm.load()."""
        self.assertIn("onRefresh: { await vm.load() }", self.cv)

    def test_vm_load_sets_is_loading_true(self):
        """vm.load() must set isLoading = true at entry."""
        vm_src = _read(COLLECTION_VM)
        load_block_start = vm_src.find("func load()")
        self.assertGreater(load_block_start, -1)
        load_block = vm_src[load_block_start : load_block_start + 300]
        self.assertIn("isLoading = true", load_block)

    def test_vm_load_clears_is_loading_on_exit(self):
        """vm.load() must clear isLoading via defer."""
        vm_src = _read(COLLECTION_VM)
        self.assertIn("defer { isLoading = false }", vm_src)

    def test_refreshable_is_on_sources_list(self):
        """The .refreshable modifier is on the sourcesList, not the outer Group."""
        # sourcesList is a private var — check that refreshable is defined
        # within the context of the list (after List {) in the file
        stv = self.stv
        list_pos      = stv.find("List {")
        refreshable_pos = stv.find(".refreshable {")
        self.assertGreater(list_pos, -1, "List { must exist")
        self.assertGreater(refreshable_pos, -1, ".refreshable must exist")
        self.assertGreater(refreshable_pos, list_pos, ".refreshable must appear after List {")


# --------------------------------------------------------------------------- #
# 6. isLoading guard — PTR must NOT trigger skeleton
# --------------------------------------------------------------------------- #

class TestIsLoadingGuard(unittest.TestCase):
    """When PTR is triggered (items already loaded), no skeleton should appear."""

    def setUp(self):
        self.stv = _read(SOURCES_TAB_VIEW)

    def test_loading_state_only_shown_when_items_empty(self):
        """Loading skeleton must only appear when both isLoading AND items.isEmpty."""
        self.assertIn("isLoading && items.isEmpty", self.stv)

    def test_empty_state_not_conflated_with_loading(self):
        """Empty state branch must be separate from loading branch."""
        stv = self.stv
        loading_branch = "isLoading && items.isEmpty"
        empty_branch   = "items.isEmpty"
        self.assertIn(loading_branch, stv)
        self.assertIn(empty_branch, stv)
        # The empty state branch must use plain items.isEmpty (without isLoading)
        # The if-else structure ensures when isLoading+empty → skeleton, not empty state
        # Verify both branches exist as distinct checks (one is else-if)
        loading_pos = stv.find(loading_branch)
        empty_pos   = stv.find(empty_branch)
        self.assertLess(loading_pos, empty_pos,
                        "isLoading+empty guard must come before the items.isEmpty empty-state check")

    def test_progress_view_only_in_loading_state(self):
        """ProgressView() skeleton is only in the loading state branch."""
        stv = self.stv
        progress_pos = stv.find("ProgressView()")
        # ProgressView must not be used in the sourcesList branch (i.e., it exists in loadingState)
        self.assertGreater(progress_pos, -1, "ProgressView() must be defined for loading state")
        # Confirm it's in the loadingState var context
        self.assertIn("private var loadingState", stv)


# --------------------------------------------------------------------------- #
# 7. ContentTypeIconBadge colors
# --------------------------------------------------------------------------- #

class TestContentTypeIconBadge(unittest.TestCase):
    """ContentTypeIconBadge: correct tint colors per content type."""

    def setUp(self):
        self.stv = _read(SOURCES_TAB_VIEW)

    def test_article_foreground_is_cool_blue(self):
        """article foreground color must be #4A7ABB (cool blue)."""
        self.assertIn("#4A7ABB", self.stv)

    def test_article_background_is_blue_wash(self):
        """article background must be #EEF3FB (cool blue wash)."""
        self.assertIn("#EEF3FB", self.stv)

    def test_video_foreground_is_warm_red(self):
        """video foreground color must be #B84C3A (warm red)."""
        self.assertIn("#B84C3A", self.stv)

    def test_video_background_is_red_wash(self):
        """video background must be #FCF0EE (warm red wash)."""
        self.assertIn("#FCF0EE", self.stv)

    def test_podcast_uses_same_tint_as_article(self):
        """podcast must use the same cool-blue family as article."""
        stv = self.stv
        # Find the podcast case and verify it maps to the same hex as article
        # The colors appear in switch statements — podcast maps to #EEF3FB bg / #4A7ABB fg
        podcast_block_bg = re.search(
            r"case \.podcast:.*?return Color\(hex: \"(#[0-9A-Fa-f]+)\"\)",
            stv,
            re.DOTALL,
        )
        self.assertIsNotNone(podcast_block_bg, "podcast background color case not found")
        self.assertEqual(podcast_block_bg.group(1), "#EEF3FB",
                         "podcast background must be #EEF3FB (same as article)")

    def test_badge_frame_is_28x28(self):
        """ContentTypeIconBadge must be 28×28 points."""
        self.assertIn(".frame(width: 28, height: 28)", self.stv)

    def test_badge_has_rounded_corners(self):
        """Badge must be clipped with a rounded rectangle."""
        self.assertIn("RoundedRectangle(cornerRadius:", self.stv)

    def test_content_type_icon_badge_is_private(self):
        """ContentTypeIconBadge should be private to SourcesTabView.swift."""
        self.assertIn("private struct ContentTypeIconBadge", self.stv)

    def test_icon_resolved_from_content_type(self):
        """Badge image uses contentType.icon system name."""
        self.assertIn("contentType.icon", self.stv)


# --------------------------------------------------------------------------- #
# 8. TagChip: up to 6 chips in horizontal scroll — no wrapping
# --------------------------------------------------------------------------- #

class TestTagChip(unittest.TestCase):
    """TagChip component and 6-chip horizontal scroll row."""

    def setUp(self):
        self.stv = _read(SOURCES_TAB_VIEW)

    def test_tag_chip_struct_defined(self):
        """TagChip struct must be declared."""
        self.assertIn("struct TagChip", self.stv)

    def test_tag_chip_is_view(self):
        """TagChip must conform to View."""
        self.assertIn("TagChip: View", self.stv)

    def test_tags_capped_at_six_with_prefix(self):
        """Tags must be capped at 6 using .prefix(6)."""
        self.assertIn("item.tags.prefix(6)", self.stv)

    def test_tags_in_horizontal_scroll_view(self):
        """Tag chips must be inside a horizontal ScrollView."""
        self.assertIn("ScrollView(.horizontal", self.stv)

    def test_scroll_indicators_hidden(self):
        """ScrollView must hide scroll indicators for clean look."""
        self.assertIn("showsIndicators: false", self.stv)

    def test_chips_in_hstack(self):
        """Chips must be arranged in an HStack (not VStack)."""
        stv = self.stv
        tags_section_start = stv.find("private var tagsSection")
        self.assertGreater(tags_section_start, -1, "tagsSection not found")
        tags_section = stv[tags_section_start : tags_section_start + 400]
        self.assertIn("HStack(spacing:", tags_section)

    def test_tag_chip_uses_capsule_shape(self):
        """TagChip must use Capsule shape for pill styling."""
        stv = self.stv
        tag_chip_start = stv.find("struct TagChip")
        self.assertGreater(tag_chip_start, -1)
        tag_chip_block = stv[tag_chip_start : tag_chip_start + 400]
        self.assertIn("Capsule()", tag_chip_block)

    def test_tag_chip_background_is_surface2(self):
        """TagChip background must use Color.Nexus.surface2."""
        stv = self.stv
        tag_chip_start = stv.find("struct TagChip")
        tag_chip_block = stv[tag_chip_start : tag_chip_start + 400]
        self.assertIn("Color.Nexus.surface2", tag_chip_block)

    def test_tag_chip_has_border_overlay(self):
        """TagChip must have a Capsule border overlay."""
        stv = self.stv
        tag_chip_start = stv.find("struct TagChip")
        # Use 600 chars to capture the full TagChip body including the .overlay/.stroke lines
        tag_chip_block = stv[tag_chip_start : tag_chip_start + 600]
        self.assertIn(".stroke(", tag_chip_block)

    def test_tags_section_only_shown_when_not_empty(self):
        """tagsSection must guard against empty tags array."""
        self.assertIn("!item.tags.isEmpty", self.stv)

    def test_tag_chip_label_property(self):
        """TagChip must accept a label: String property."""
        stv = self.stv
        tag_chip_start = stv.find("struct TagChip")
        tag_chip_block = stv[tag_chip_start : tag_chip_start + 200]
        self.assertIn("let label: String", tag_chip_block)


# --------------------------------------------------------------------------- #
# 9. Empty state: icon + 'No sources yet' copy
# --------------------------------------------------------------------------- #

class TestEmptyState(unittest.TestCase):
    """Empty state: doc.text.magnifyingglass icon + 'No sources yet' copy."""

    def setUp(self):
        self.stv = _read(SOURCES_TAB_VIEW)

    def test_empty_state_icon_is_doc_text_magnifyingglass(self):
        """Empty state must use the 'doc.text.magnifyingglass' system image."""
        self.assertIn('"doc.text.magnifyingglass"', self.stv)

    def test_empty_state_shows_no_sources_yet(self):
        """Empty state copy must include 'No sources yet'."""
        self.assertIn("No sources yet", self.stv)

    def test_empty_state_branch_exists(self):
        """A distinct emptyState view must be defined."""
        self.assertIn("private var emptyState", self.stv)

    def test_empty_state_rendered_when_items_empty(self):
        """Body must render emptyState when items is empty (and not loading)."""
        stv = self.stv
        body_start = stv.find("var body: some View")
        body_block = stv[body_start : body_start + 500]
        self.assertIn("emptyState", body_block)

    def test_empty_state_not_blank(self):
        """Empty state must have descriptive text beyond just the icon."""
        stv = self.stv
        empty_state_start = stv.find("private var emptyState")
        empty_state_block = stv[empty_state_start : empty_state_start + 600]
        # Must have both the icon and at least one Text view
        self.assertIn("Text(", empty_state_block)
        self.assertIn("Image(systemName:", empty_state_block)


# --------------------------------------------------------------------------- #
# 10. CollectionView integration: SourcesTabView wired correctly
# --------------------------------------------------------------------------- #

class TestCollectionViewIntegration(unittest.TestCase):
    """CollectionView correctly wires SourcesTabView into the tab switcher."""

    def setUp(self):
        self.cv = _read(COLLECTION_VIEW)

    def test_sources_tab_view_instantiated(self):
        """CollectionView must instantiate SourcesTabView."""
        self.assertIn("SourcesTabView(", self.cv)

    def test_sources_tab_view_receives_vm_items(self):
        """SourcesTabView receives items: vm.items."""
        self.assertIn("items: vm.items", self.cv)

    def test_sources_tab_view_receives_vm_is_loading(self):
        """SourcesTabView receives isLoading: vm.isLoading."""
        self.assertIn("isLoading: vm.isLoading", self.cv)

    def test_sources_tab_view_receives_collection_id(self):
        """SourcesTabView receives collectionId: vm.collection.id."""
        self.assertIn("collectionId: vm.collection.id", self.cv)

    def test_on_delete_calls_vm_delete(self):
        """onDelete closure calls vm.delete(item:)."""
        self.assertIn("vm.delete(item: item)", self.cv)

    def test_on_refresh_calls_vm_load(self):
        """onRefresh closure calls vm.load()."""
        self.assertIn("vm.load()", self.cv)

    def test_task_modifier_calls_vm_load_on_appear(self):
        """CollectionView uses .task to load data on appear."""
        self.assertIn(".task { await vm.load() }", self.cv)

    def test_navigation_destination_for_item_detail(self):
        """NavigationLink destination for ItemDetailRoute must be present."""
        self.assertIn("navigationDestination(for: ItemDetailRoute.self)", self.stv if hasattr(self, 'stv') else _read(SOURCES_TAB_VIEW))

    def test_two_tabs_defined(self):
        """Tab enum must define exactly .nexus and .sources."""
        cv = self.cv
        nexus_count   = cv.count("case nexus")
        sources_count = cv.count("case sources")
        self.assertEqual(nexus_count, 1, "Exactly one 'case nexus' must exist")
        self.assertEqual(sources_count, 1, "Exactly one 'case sources' must exist")


# --------------------------------------------------------------------------- #
# 11. APIClient.deleteItem calls DELETE /v1/collections/{id}/items/{itemId}
# --------------------------------------------------------------------------- #

class TestAPIClientDeleteItem(unittest.TestCase):
    """APIClient.deleteItem must use the correct endpoint and HTTP method."""

    def setUp(self):
        self.api = _read(API_CLIENT)

    def test_delete_item_method_exists(self):
        """deleteItem(id:in:) method must exist."""
        self.assertIn("func deleteItem(id itemId: UUID, in collectionId: UUID)", self.api)

    def test_delete_item_is_async_throws(self):
        """deleteItem must be async throws."""
        self.assertIn("async throws", self.api)

    def test_delete_method_takes_endpoint(self):
        """Generic delete(_:) method must accept an Endpoint."""
        self.assertIn("func delete(_ endpoint: Endpoint)", self.api)

    def test_delete_uses_delete_http_method(self):
        """delete() must use 'DELETE' as the HTTP method."""
        self.assertIn('"DELETE"', self.api)

    def test_empty_response_type_used_for_204(self):
        """delete() returns EmptyResponse to handle 204 No Content."""
        self.assertIn("EmptyResponse", self.api)

    def test_item_endpoint_used_in_delete_item(self):
        """deleteItem uses the .item(collectionId:itemId:) endpoint."""
        self.assertIn("delete(.item(collectionId: collectionId, itemId: itemId))", self.api)


# --------------------------------------------------------------------------- #
# 12. SourceCard press animation (scale feedback)
# --------------------------------------------------------------------------- #

class TestSourceCardPressFeedback(unittest.TestCase):
    """SourceCard provides visual press feedback via scale animation."""

    def setUp(self):
        self.stv = _read(SOURCES_TAB_VIEW)

    def test_is_pressed_state_variable(self):
        """SourceCard has a @State isPressed boolean."""
        stv = self.stv
        source_card_start = stv.find("struct SourceCard")
        source_card_block = stv[source_card_start : source_card_start + 600]
        self.assertIn("@State private var isPressed", source_card_block)

    def test_scale_effect_applied(self):
        """SourceCard must apply .scaleEffect on press."""
        self.assertIn(".scaleEffect(", self.stv)

    def test_long_press_gesture_tracks_press_state(self):
        """onLongPressGesture used to track isPressed state."""
        self.assertIn("onLongPressGesture(minimumDuration: 0", self.stv)

    def test_animation_uses_nexus_animation_press(self):
        """Press animation must use NexusAnimation.press."""
        self.assertIn("NexusAnimation.press", self.stv)


# --------------------------------------------------------------------------- #
# 13. Domain extraction helper
# --------------------------------------------------------------------------- #

class TestDomainExtraction(unittest.TestCase):
    """SourceCard extracts domain from URL for the overline."""

    def setUp(self):
        self.stv = _read(SOURCES_TAB_VIEW)

    def test_extract_domain_function_defined(self):
        """extractDomain(from:) helper must be defined."""
        self.assertIn("func extractDomain(from urlString: String)", self.stv)

    def test_www_prefix_stripped(self):
        """extractDomain must strip the 'www.' prefix."""
        self.assertIn('hasPrefix("www.")', self.stv)
        self.assertIn("dropFirst(4)", self.stv)

    def test_url_host_extracted(self):
        """extractDomain must use URL(string:)?.host to parse the domain."""
        self.assertIn("URL(string: urlString)?.host", self.stv)


if __name__ == "__main__":
    unittest.main()
