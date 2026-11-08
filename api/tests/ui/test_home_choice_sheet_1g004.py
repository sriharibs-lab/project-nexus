"""
Tests for task 1G-004 — HomeView new-collection choice sheet.

Validates:
  1. File existence for created/modified Swift files.
  2. HomeView: showingChoiceSheet state, '+' toolbar button, sheet presentation at 240pt.
  3. NewCollectionChoiceSheet: two choice rows, "Research a topic" + "Start with a link".
  4. Choice sheet: dismissal + navigation to ResearchFlowView (fullScreenCover) and LinkURLSheetView (sheet).
  5. LinkURLViewModel: empty fields → "Please fill in both fields." error.
  6. LinkURLViewModel: invalid URL → "Please enter a valid URL starting with https://." error.
  7. LinkURLViewModel: canSave guard (requires both fields non-empty and not .saving).
  8. LinkURLViewModel: phase transitions: idle → saving → done(id) or error.
  9. LinkURLSheetView: structure — NavigationStack, Cancel button, CTA spinner on saving, errorMessage rendered.
  10. APIClient SSE fix: break on type='done' and type='error' to prevent stream stalling.
  11. ResearchFlowView: onComplete callback navigates to new collection.

No iOS simulator required — pure Python text inspection of Swift sources.
"""

from __future__ import annotations
import pathlib as _pl; _REPO_ROOT = str(_pl.Path(__file__).resolve().parents[3])  # repo root, portable

import os
import re
import unittest

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

_WORKTREE = _REPO_ROOT + "/.claude/worktrees/wf_5a6a2270-719-9"
_MAIN = _REPO_ROOT + ""


def _wt(rel: str) -> str:
    """Return worktree path when present, else fall back to main tree."""
    wt = os.path.join(_WORKTREE, rel)
    mt = os.path.join(_MAIN, rel)
    return wt if os.path.exists(wt) else mt


HOME_VIEW = _wt("app-ios/Nexus/Nexus/Features/Home/HomeView.swift")
LINK_URL_SHEET = _wt("app-ios/Nexus/Nexus/Features/Home/LinkURLSheetView.swift")
LINK_URL_VM = _wt("app-ios/Nexus/Nexus/Features/Home/LinkURLViewModel.swift")
API_CLIENT = _wt("app-ios/Nexus/Nexus/Core/Network/APIClient.swift")
RESEARCH_FLOW = _wt("app-ios/Nexus/Nexus/Features/Research/ResearchFlowView.swift")


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


# ---------------------------------------------------------------------------
# 1. File existence
# ---------------------------------------------------------------------------


class TestFileExistence(unittest.TestCase):
    """All created/modified files must be present in the worktree."""

    def test_home_view_exists(self):
        self.assertTrue(os.path.exists(HOME_VIEW), f"Not found: {HOME_VIEW}")

    def test_link_url_sheet_view_exists(self):
        self.assertTrue(os.path.exists(LINK_URL_SHEET), f"Not found: {LINK_URL_SHEET}")

    def test_link_url_view_model_exists(self):
        self.assertTrue(os.path.exists(LINK_URL_VM), f"Not found: {LINK_URL_VM}")

    def test_api_client_exists(self):
        self.assertTrue(os.path.exists(API_CLIENT), f"Not found: {API_CLIENT}")

    def test_research_flow_view_exists(self):
        self.assertTrue(os.path.exists(RESEARCH_FLOW), f"Not found: {RESEARCH_FLOW}")


# ---------------------------------------------------------------------------
# 2. HomeView — choice sheet state and '+' toolbar
# ---------------------------------------------------------------------------


class TestHomeViewChoiceSheetState(unittest.TestCase):
    """HomeView must declare the three State booleans driving the creation flows."""

    def setUp(self):
        self.src = _read(HOME_VIEW)

    def test_showing_choice_sheet_state(self):
        """@State showingChoiceSheet must be declared."""
        self.assertIn("showingChoiceSheet", self.src)

    def test_showing_research_flow_state(self):
        """@State showingResearchFlow must be declared."""
        self.assertIn("showingResearchFlow", self.src)

    def test_showing_link_sheet_state(self):
        """@State showingLinkSheet must be declared."""
        self.assertIn("showingLinkSheet", self.src)

    def test_plus_button_sets_choice_sheet(self):
        """Toolbar '+' button must set showingChoiceSheet = true."""
        self.assertIn("showingChoiceSheet = true", self.src)

    def test_plus_button_uses_system_image(self):
        """Toolbar button uses the SF Symbol 'plus'."""
        self.assertIn('"plus"', self.src)

    def test_nav_path_declared(self):
        """NavigationPath must be declared for programmatic navigation."""
        self.assertIn("NavigationPath", self.src)


# ---------------------------------------------------------------------------
# 3. HomeView — sheet presentation configuration
# ---------------------------------------------------------------------------


class TestHomeViewSheetPresentation(unittest.TestCase):
    """Sheet must be presented with the correct configuration."""

    def setUp(self):
        self.src = _read(HOME_VIEW)

    def test_choice_sheet_height_240(self):
        """Choice sheet must use .height(240) detent."""
        self.assertIn(".height(240)", self.src)

    def test_choice_sheet_drag_indicator_visible(self):
        """Choice sheet must show the drag indicator."""
        self.assertIn(".presentationDragIndicator(.visible)", self.src)

    def test_choice_sheet_card_background(self):
        """Choice sheet background must use Nexus card background color."""
        self.assertIn("presentationBackground", self.src)
        self.assertIn("cardBackground", self.src)

    def test_link_sheet_large_detent(self):
        """LinkURLSheetView must be presented with .large detent."""
        self.assertIn(".large", self.src)

    def test_research_flow_full_screen_cover(self):
        """ResearchFlowView must be opened as a fullScreenCover."""
        self.assertIn("fullScreenCover", self.src)
        self.assertIn("showingResearchFlow", self.src)


# ---------------------------------------------------------------------------
# 4. NewCollectionChoiceSheet component
# ---------------------------------------------------------------------------


class TestNewCollectionChoiceSheet(unittest.TestCase):
    """NewCollectionChoiceSheet must contain both creation options."""

    def setUp(self):
        self.src = _read(HOME_VIEW)

    def test_choice_sheet_struct_declared(self):
        """NewCollectionChoiceSheet struct must be declared."""
        self.assertIn("NewCollectionChoiceSheet", self.src)

    def test_on_research_callback(self):
        """Choice sheet must expose an onResearch callback."""
        self.assertIn("onResearch", self.src)

    def test_on_link_callback(self):
        """Choice sheet must expose an onLink callback."""
        self.assertIn("onLink", self.src)

    def test_research_a_topic_label(self):
        """'Research a topic' option must be present in the choice sheet."""
        self.assertIn("Research a topic", self.src)

    def test_start_with_a_link_label(self):
        """'Start with a link' option must be present in the choice sheet."""
        self.assertIn("Start with a link", self.src)

    def test_new_collection_header(self):
        """Sheet header must display 'NEW COLLECTION' (or similar section label)."""
        self.assertIn("NEW COLLECTION", self.src)

    def test_sparkles_icon(self):
        """Research option must use the 'sparkles' SF Symbol."""
        self.assertIn('"sparkles"', self.src)

    def test_link_icon(self):
        """Link option must use the 'link' SF Symbol."""
        self.assertIn('"link"', self.src)

    def test_on_research_dismisses_choice_sheet(self):
        """Tapping Research must dismiss the choice sheet first."""
        # The handler sets showingChoiceSheet = false before opening research flow
        self.assertIn("showingChoiceSheet = false", self.src)

    def test_on_link_dismisses_choice_sheet(self):
        """Tapping Start with a link must also dismiss the choice sheet."""
        # Same state variable toggled off before opening link sheet
        # (checked implicitly by the single showingChoiceSheet = false assertion above
        #  since both handlers use the same pattern)
        src = self.src
        # Count occurrences — both handlers must set it to false
        count = src.count("showingChoiceSheet = false")
        self.assertGreaterEqual(count, 2, "Both choice rows must dismiss the sheet")


# ---------------------------------------------------------------------------
# 5. ChoiceRow subcomponent
# ---------------------------------------------------------------------------


class TestChoiceRowComponent(unittest.TestCase):
    """ChoiceRow private struct: press animation, icon badge, chevron."""

    def setUp(self):
        self.src = _read(HOME_VIEW)

    def test_choice_row_struct_declared(self):
        """ChoiceRow private struct must be present."""
        self.assertIn("struct ChoiceRow", self.src)

    def test_choice_row_chevron(self):
        """Each ChoiceRow must show a chevron.right indicator."""
        self.assertIn("chevron.right", self.src)

    def test_choice_row_icon_badge(self):
        """ChoiceRow must render an icon inside a rounded badge."""
        self.assertIn("RoundedRectangle", self.src)

    def test_choice_row_press_animation(self):
        """ChoiceRow must have press-state animation."""
        self.assertIn("isPressed", self.src)
        self.assertIn("scaleEffect", self.src)


# ---------------------------------------------------------------------------
# 6. Navigation to new collection after completion
# ---------------------------------------------------------------------------


class TestHomeViewNavigationOnComplete(unittest.TestCase):
    """After either flow completes, HomeView reloads and pushes the new collection."""

    def setUp(self):
        self.src = _read(HOME_VIEW)

    def test_on_complete_reloads_vm(self):
        """onComplete handler must call vm.load()."""
        self.assertIn("vm.load()", self.src)

    def test_on_complete_appends_to_nav_path(self):
        """onComplete must append the found collection to navPath."""
        self.assertIn("navPath.append", self.src)

    def test_navigation_destination_for_collection(self):
        """NavigationStack must have a .navigationDestination for NexusCollection."""
        self.assertIn("navigationDestination", self.src)
        self.assertIn("NexusCollection", self.src)

    def test_research_flow_on_complete_navigates(self):
        """ResearchFlowView inside fullScreenCover also receives onComplete."""
        # The full-screen ResearchFlowView block must also call navPath.append
        src = self.src
        full_screen_start = src.find("fullScreenCover")
        self.assertGreater(full_screen_start, -1, "fullScreenCover not found")
        block = src[full_screen_start:full_screen_start + 400]
        self.assertIn("navPath.append", block)

    def test_link_sheet_on_complete_navigates(self):
        """LinkURLSheetView inside sheet also receives onComplete."""
        src = self.src
        link_sheet_start = src.find("LinkURLSheetView")
        self.assertGreater(link_sheet_start, -1, "LinkURLSheetView not found in HomeView")
        block = src[link_sheet_start:link_sheet_start + 400]
        self.assertIn("navPath.append", block)


# ---------------------------------------------------------------------------
# 7. LinkURLViewModel — validation logic
# ---------------------------------------------------------------------------


class TestLinkURLViewModelValidation(unittest.TestCase):
    """LinkURLViewModel must validate inputs before saving."""

    def setUp(self):
        self.src = _read(LINK_URL_VM)

    def test_view_model_class_declared(self):
        """LinkURLViewModel class must be declared."""
        self.assertIn("class LinkURLViewModel", self.src)

    def test_url_text_published(self):
        """urlText must be a @Published property."""
        self.assertIn("var urlText", self.src)

    def test_collection_name_published(self):
        """collectionName must be a @Published property."""
        self.assertIn("var collectionName", self.src)

    def test_phase_published(self):
        """phase must be a @Published property of type LinkURLPhase."""
        self.assertIn("phase", self.src)
        self.assertIn("LinkURLPhase", self.src)

    def test_error_message_published(self):
        """errorMessage must be a @Published property."""
        self.assertIn("errorMessage", self.src)

    def test_can_save_requires_non_empty_url(self):
        """canSave must check that urlText is non-empty."""
        self.assertIn("urlText", self.src)
        # canSave should do a trimming check
        self.assertIn("isEmpty", self.src)

    def test_can_save_requires_non_empty_name(self):
        """canSave must check that collectionName is non-empty."""
        self.assertIn("collectionName", self.src)

    def test_empty_fields_error_message(self):
        """When both fields are empty, error is 'Please fill in both fields.'"""
        self.assertIn("Please fill in both fields.", self.src)

    def test_invalid_url_error_message(self):
        """When URL lacks https:// prefix, the correct error message must appear."""
        self.assertIn("Please enter a valid URL starting with https://.", self.src)

    def test_url_prefix_guard(self):
        """Validation must check that URL starts with 'http'."""
        self.assertIn('hasPrefix("http")', self.src)

    def test_can_save_blocks_during_saving(self):
        """canSave must be false while phase == .saving."""
        self.assertIn(".saving", self.src)
        self.assertIn("phase != .saving", self.src)


# ---------------------------------------------------------------------------
# 8. LinkURLPhase enum
# ---------------------------------------------------------------------------


class TestLinkURLPhaseEnum(unittest.TestCase):
    """LinkURLPhase must declare the four required cases."""

    def setUp(self):
        self.src = _read(LINK_URL_VM)

    def test_enum_declared(self):
        self.assertIn("enum LinkURLPhase", self.src)

    def test_idle_case(self):
        self.assertIn("case idle", self.src)

    def test_saving_case(self):
        self.assertIn("case saving", self.src)

    def test_done_case_with_uuid(self):
        """done case must carry a UUID (the new collection id)."""
        self.assertIn("case done(UUID)", self.src)

    def test_error_case(self):
        """error case must carry the message string."""
        self.assertIn("case error(String)", self.src)

    def test_equatable_conformance(self):
        """LinkURLPhase must conform to Equatable for canSave guard."""
        self.assertIn("Equatable", self.src)


# ---------------------------------------------------------------------------
# 9. LinkURLViewModel — save flow
# ---------------------------------------------------------------------------


class TestLinkURLViewModelSaveFlow(unittest.TestCase):
    """save() must transition through the correct phase sequence."""

    def setUp(self):
        self.src = _read(LINK_URL_VM)

    def test_save_function_declared(self):
        """func save() must be declared async."""
        self.assertIn("func save()", self.src)
        self.assertIn("async", self.src)

    def test_save_sets_saving_phase(self):
        """save() must set phase = .saving before API calls."""
        self.assertIn("phase = .saving", self.src)

    def test_save_calls_create_collection(self):
        """save() must call APIClient.shared.createCollection(...)."""
        self.assertIn("createCollection", self.src)

    def test_save_calls_ingest(self):
        """save() must enqueue ingest after creating the collection."""
        self.assertIn("ingest(", self.src)

    def test_save_sets_done_phase(self):
        """On success, save() must set phase = .done(collection.id)."""
        self.assertIn("phase = .done(collection.id)", self.src)

    def test_save_sets_idle_on_error(self):
        """On API error, save() must reset phase to .idle."""
        self.assertIn("phase = .idle", self.src)

    def test_save_populates_error_message_on_api_error(self):
        """On error, save() must set errorMessage."""
        # Both the catch branches set errorMessage
        self.assertIn("errorMessage =", self.src)

    def test_save_clears_error_message_before_call(self):
        """save() must clear errorMessage = nil before the API call."""
        self.assertIn("errorMessage = nil", self.src)

    def test_ingest_is_fire_and_forget(self):
        """Ingest failure must be tolerated (try?) — fire-and-forget pattern."""
        self.assertIn("try?", self.src)


# ---------------------------------------------------------------------------
# 10. LinkURLSheetView — UI structure
# ---------------------------------------------------------------------------


class TestLinkURLSheetViewStructure(unittest.TestCase):
    """LinkURLSheetView: struct declared, key UI elements present."""

    def setUp(self):
        self.src = _read(LINK_URL_SHEET)

    def test_struct_declared(self):
        self.assertIn("struct LinkURLSheetView: View", self.src)

    def test_on_complete_callback(self):
        """onComplete callback with UUID must be present."""
        self.assertIn("onComplete: (UUID)", self.src)

    def test_cancel_button_present(self):
        """Cancel toolbar button must be present."""
        self.assertIn('"Cancel"', self.src)

    def test_cancel_calls_dismiss(self):
        """Cancel button must call dismiss()."""
        self.assertIn("dismiss()", self.src)

    def test_create_collection_cta(self):
        """CTA button must say 'Create Collection'."""
        self.assertIn("Create Collection", self.src)

    def test_url_field_present(self):
        """URL text field must be wired to vm.urlText."""
        self.assertIn("vm.urlText", self.src)

    def test_collection_name_field_present(self):
        """Collection name field must be wired to vm.collectionName."""
        self.assertIn("vm.collectionName", self.src)

    def test_error_message_rendered(self):
        """Error message must be rendered inline when vm.errorMessage is set."""
        self.assertIn("vm.errorMessage", self.src)
        self.assertIn("errorMessage", self.src)

    def test_spinner_on_saving(self):
        """CTA must show a ProgressView spinner during .saving phase."""
        self.assertIn("ProgressView", self.src)
        self.assertIn(".saving", self.src)

    def test_navigation_stack_wrapper(self):
        """Sheet must be wrapped in a NavigationStack (for toolbar Cancel)."""
        self.assertIn("NavigationStack", self.src)

    def test_on_done_phase_dismisses_and_navigates(self):
        """onChange of vm.phase must dismiss and call onComplete when .done."""
        self.assertIn("onChange(of: vm.phase)", self.src)
        self.assertIn("case .done(let id)", self.src)
        self.assertIn("onComplete(id)", self.src)

    def test_large_detent_hint(self):
        """Sheet is presented with .large detent (set by caller in HomeView)."""
        # This is set on the caller side (HomeView), but presentationDetents may also
        # appear in the view itself — check the caller ensures .large is referenced.
        home_src = _read(HOME_VIEW)
        self.assertIn("presentationDetents([.large])", home_src)

    def test_cta_disabled_when_cannot_save(self):
        """CTA button must be disabled when vm.canSave is false."""
        self.assertIn("vm.canSave", self.src)
        self.assertIn(".disabled", self.src)

    def test_start_with_a_link_header(self):
        """Sheet must display a 'START WITH A LINK' header."""
        self.assertIn("START WITH A LINK", self.src)


# ---------------------------------------------------------------------------
# 11. APIClient SSE — terminal event handling (SSE fix)
# ---------------------------------------------------------------------------


class TestAPIClientSSETermination(unittest.TestCase):
    """
    APIClient.streamSSE must break on both terminal event keys:
    - Research stream uses 'event' key with value 'done'/'error'
    - Chat stream uses 'type' key with value 'done'/'error'
    The SSE fix ensures the consumer breaks the loop on type:'done' so the
    connection is not held open after the response completes.
    """

    def setUp(self):
        self.src = _read(API_CLIENT)

    def test_stream_sse_function_declared(self):
        """streamSSE function must be declared in APIClient."""
        self.assertIn("func streamSSE", self.src)

    def test_breaks_on_done_terminal(self):
        """Stream loop must break when terminal value is 'done'."""
        self.assertIn('"done"', self.src)
        self.assertIn("break", self.src)

    def test_breaks_on_error_terminal(self):
        """Stream loop must break when terminal value is 'error'."""
        self.assertIn('"error"', self.src)

    def test_checks_event_key(self):
        """Must check dict['event'] key for research stream terminal events."""
        self.assertIn('"event"', self.src)

    def test_checks_type_key(self):
        """Must check dict['type'] key for chat stream terminal events (SSE fix)."""
        self.assertIn('"type"', self.src)

    def test_coalesces_both_keys(self):
        """Both 'event' and 'type' keys must be checked via ?? fallback."""
        # The fix pattern: (dict["event"] as? String) ?? (dict["type"] as? String) ?? ""
        src = self.src
        # Verify the two keys appear together in the termination logic block.
        # Use 2500 chars to ensure we cover the full function body.
        sse_fn_start = src.find("func streamSSE")
        self.assertGreater(sse_fn_start, -1)
        sse_block = src[sse_fn_start:sse_fn_start + 2500]
        self.assertIn('"event"', sse_block)
        self.assertIn('"type"', sse_block)
        self.assertIn("break", sse_block)

    def test_no_stall_after_done_event(self):
        """The break statement must follow the terminal-value check (not deep inside)."""
        src = self.src
        # Find the terminal check block
        term_match = re.search(
            r'terminalValue.*?=="done".*?break|break.*?terminalValue.*?=="done"',
            src,
            re.DOTALL,
        )
        # If not that pattern, look for the combined pattern
        if term_match is None:
            term_match = re.search(
                r'if terminalValue[^\n]+\n\s+break',
                src,
            )
        self.assertIsNotNone(
            term_match,
            "break must be triggered by the terminal value check"
        )

    def test_sse_parses_data_prefix(self):
        """SSE parser must strip the 'data: ' prefix from each line."""
        self.assertIn('"data: "', self.src)

    def test_async_bytes_lines(self):
        """Stream must consume asyncBytes.lines (async line-by-line)."""
        self.assertIn("asyncBytes.lines", self.src)


# ---------------------------------------------------------------------------
# 12. ResearchFlowView — onComplete integration
# ---------------------------------------------------------------------------


class TestResearchFlowViewOnComplete(unittest.TestCase):
    """ResearchFlowView must accept and fire onComplete with the new collection UUID."""

    def setUp(self):
        self.src = _read(RESEARCH_FLOW)

    def test_on_complete_property_declared(self):
        """onComplete: (UUID) -> Void must be declared."""
        self.assertIn("onComplete: (UUID)", self.src)

    def test_on_complete_fired_on_done_phase(self):
        """onChange of vm.phase must call onComplete when phase is .done."""
        self.assertIn("onComplete(id)", self.src)

    def test_dismiss_called_before_on_complete(self):
        """dismiss() must be called before onComplete to let the cover close."""
        src = self.src
        dismiss_idx = src.find("dismiss()")
        on_complete_idx = src.find("onComplete(id)")
        self.assertGreater(dismiss_idx, -1, "dismiss() not found in ResearchFlowView")
        self.assertGreater(on_complete_idx, -1, "onComplete(id) not found in ResearchFlowView")
        self.assertLess(dismiss_idx, on_complete_idx,
                        "dismiss() must come before onComplete(id)")

    def test_on_change_of_vm_phase(self):
        """onChange(of: vm.phase) must be used to detect completion."""
        self.assertIn("onChange(of: vm.phase)", self.src)


if __name__ == "__main__":
    unittest.main()
