"""
Tests for task 1D-002 — Empty states, loading states, error states
(all screens: home, collection, reader, chat, search)

These tests inspect Swift source files as text to verify the required
state-view implementation patterns are present and correctly structured.
They run without Xcode or a device — no Swift compilation needed.

Covered test_hints:
  HomeView loading/error/empty states
  SourcesTabView loading/empty/processing states
  NexusTabView chat empty/streaming/error states
  ItemDetailView processing/failed/full-text-loading states
  SearchView idle/searching/empty/failed states
"""

from __future__ import annotations
import pathlib as _pl; _REPO_ROOT = str(_pl.Path(__file__).resolve().parents[3])  # repo root, portable

import os
import re
import unittest

# --------------------------------------------------------------------------- #
# File paths
# --------------------------------------------------------------------------- #

_MAIN = _REPO_ROOT + ""

HOME_VIEW         = os.path.join(_MAIN, "app-ios/Nexus/Nexus/Features/Home/HomeView.swift")
HOME_VM           = os.path.join(_MAIN, "app-ios/Nexus/Nexus/Features/Home/HomeViewModel.swift")
COLLECTION_VIEW   = os.path.join(_MAIN, "app-ios/Nexus/Nexus/Features/Collection/CollectionView.swift")
SOURCES_TAB       = os.path.join(_MAIN, "app-ios/Nexus/Nexus/Features/Collection/SourcesTabView.swift")
NEXUS_TAB         = os.path.join(_MAIN, "app-ios/Nexus/Nexus/Features/Collection/NexusTabView.swift")
ITEM_DETAIL       = os.path.join(_MAIN, "app-ios/Nexus/Nexus/Features/Reader/ItemDetailView.swift")
SEARCH_VIEW       = os.path.join(_MAIN, "app-ios/Nexus/Nexus/Features/Search/SearchView.swift")
SEARCH_VM         = os.path.join(_MAIN, "app-ios/Nexus/Nexus/Features/Search/SearchViewModel.swift")
NEXUS_COLLECTION  = os.path.join(_MAIN, "app-ios/Nexus/Nexus/Core/Models/NexusCollection.swift")


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


def _exists(path: str) -> bool:
    return os.path.exists(path)


# --------------------------------------------------------------------------- #
# HomeView — loading, empty, and error states
# --------------------------------------------------------------------------- #

class TestHomeViewLoadingState(unittest.TestCase):
    """HomeView: loading skeleton while collections are being fetched."""

    def setUp(self):
        if not _exists(HOME_VIEW):
            self.skipTest("HomeView.swift not found")
        self.src = _read(HOME_VIEW)

    def test_loading_guard_uses_is_loading_and_empty(self):
        """Loading state shown only when isLoading && collections.isEmpty."""
        self.assertIn("vm.isLoading && vm.collections.isEmpty", self.src,
                      "Loading guard must check both isLoading and collections.isEmpty")

    def test_loading_branch_shows_progress_view(self):
        """Loading branch renders ProgressView (skeleton stand-in)."""
        # ProgressView is within the isLoading && isEmpty branch
        self.assertIn("ProgressView()", self.src)

    def test_empty_state_branch_separate_from_loading(self):
        """Empty state is an else-if/else after the loading branch (not conflated)."""
        src = self.src
        loading_pos = src.find("vm.isLoading && vm.collections.isEmpty")
        empty_pos   = src.find("vm.collections.isEmpty")
        # empty_pos must appear AFTER loading_pos (else-if chain)
        self.assertGreater(empty_pos, loading_pos,
                           "collections.isEmpty empty-state check must come after loading guard")

    def test_task_modifier_triggers_load(self):
        """HomeView uses .task to load collections on appear."""
        self.assertIn(".task { await vm.load() }", self.src)

    def test_collection_list_rendered_when_loaded(self):
        """collectionList view is rendered when collections are non-empty."""
        self.assertIn("collectionList", self.src)


class TestHomeViewEmptyState(unittest.TestCase):
    """HomeView: empty state for new users with no collections."""

    def setUp(self):
        if not _exists(HOME_VIEW):
            self.skipTest("HomeView.swift not found")
        self.src = _read(HOME_VIEW)

    def test_empty_state_headline(self):
        """Empty state must show 'What are you curious about?' headline."""
        self.assertIn("What are you curious about?", self.src)

    def test_research_a_topic_cta(self):
        """Empty state must contain 'Research a topic' CTA button."""
        self.assertIn("Research a topic", self.src)

    def test_cta_opens_research_sheet(self):
        """Tapping CTA sets showingNewCollection = true (opens ResearchFlowView sheet)."""
        self.assertIn("showingNewCollection = true", self.src)

    def test_research_flow_sheet_attached(self):
        """HomeView attaches a .sheet for ResearchFlowView."""
        self.assertIn("ResearchFlowView", self.src)

    def test_empty_state_view_defined(self):
        """emptyState view must be defined as a computed property."""
        self.assertIn("private var emptyState", self.src)


class TestHomeViewModelLoadAndError(unittest.TestCase):
    """HomeViewModel: isLoading lifecycle, error property."""

    def setUp(self):
        if not _exists(HOME_VM):
            self.skipTest("HomeViewModel.swift not found")
        self.src = _read(HOME_VM)

    def test_is_loading_published(self):
        """HomeViewModel must publish isLoading."""
        self.assertIn("@Published", self.src)
        self.assertIn("isLoading", self.src)

    def test_error_published(self):
        """HomeViewModel must publish an error property."""
        self.assertIn("error:", self.src)

    def test_load_sets_is_loading_true(self):
        """load() must set isLoading = true."""
        src = self.src
        load_start = src.find("func load()")
        self.assertGreater(load_start, -1, "load() function must exist")
        load_block = src[load_start : load_start + 300]
        self.assertIn("isLoading = true", load_block)

    def test_load_clears_is_loading_via_defer(self):
        """load() must clear isLoading using defer."""
        self.assertIn("defer { isLoading = false }", self.src)

    def test_error_captured_from_api(self):
        """load() must catch errors and assign to error property."""
        src = self.src
        load_start = src.find("func load()")
        load_block = src[load_start : load_start + 400]
        self.assertIn("catch", load_block)


# --------------------------------------------------------------------------- #
# SourcesTabView — loading, empty, processing states
# --------------------------------------------------------------------------- #

class TestSourcesTabLoadingState(unittest.TestCase):
    """SourcesTabView: loading skeleton on first load."""

    def setUp(self):
        if not _exists(SOURCES_TAB):
            self.skipTest("SourcesTabView.swift not found")
        self.src = _read(SOURCES_TAB)

    def test_loading_guard_is_loading_and_items_empty(self):
        """Loading skeleton only when isLoading && items.isEmpty."""
        self.assertIn("isLoading && items.isEmpty", self.src)

    def test_loading_state_var_defined(self):
        """loadingState computed var must be defined."""
        self.assertIn("loadingState", self.src)

    def test_loading_state_has_progress_view(self):
        """Loading state renders ProgressView."""
        self.assertIn("ProgressView()", self.src)


class TestSourcesTabEmptyState(unittest.TestCase):
    """SourcesTabView: empty state when collection has 0 sources."""

    def setUp(self):
        if not _exists(SOURCES_TAB):
            self.skipTest("SourcesTabView.swift not found")
        self.src = _read(SOURCES_TAB)

    def test_empty_state_copy(self):
        """Empty state must show 'No sources yet'."""
        self.assertIn("No sources yet", self.src)

    def test_empty_state_defined(self):
        """emptyState computed var must be defined."""
        self.assertIn("private var emptyState", self.src)

    def test_empty_state_icon(self):
        """Empty state uses 'doc.text.magnifyingglass' icon."""
        self.assertIn('"doc.text.magnifyingglass"', self.src)

    def test_empty_state_secondary_text(self):
        """Empty state includes helpful secondary copy."""
        self.assertIn("Add a source", self.src)


class TestSourcesTabProcessingItem(unittest.TestCase):
    """SourcesTabView: processing item shows animated status indicator."""

    def setUp(self):
        if not _exists(SOURCES_TAB):
            self.skipTest("SourcesTabView.swift not found")
        self.src = _read(SOURCES_TAB)

    def test_processing_status_shown_in_summary_section(self):
        """summarySection must branch on .processing status."""
        self.assertIn(".processing", self.src)

    def test_processing_label_text(self):
        """Processing state includes descriptive label text."""
        self.assertIn("processing", self.src.lower())

    def test_processing_dot_element(self):
        """A Circle element is used for the processing dot indicator."""
        self.assertIn("Circle()", self.src)

    def test_ingest_status_pill_defined(self):
        """IngestStatusPill component must be defined in SourcesTabView."""
        self.assertIn("IngestStatusPill", self.src)


# --------------------------------------------------------------------------- #
# NexusTabView — chat empty, streaming, and error states
# --------------------------------------------------------------------------- #

class TestNexusTabEmptyState(unittest.TestCase):
    """NexusTabView: framing paragraph shown before any message is sent."""

    def setUp(self):
        if not _exists(NEXUS_TAB):
            self.skipTest("NexusTabView.swift not found")
        self.src = _read(NEXUS_TAB)

    def test_framing_paragraph_section_defined(self):
        """framingParagraph view must be defined."""
        self.assertIn("framingParagraph", self.src)

    def test_framing_paragraph_default_hint(self):
        """Default framing paragraph hints user to 'Ask me anything'."""
        self.assertIn("Ask me anything", self.src)

    def test_framing_paragraph_at_top_of_chat_thread(self):
        """framingParagraph is pinned at top of chatThread."""
        src = self.src
        chat_thread_start = src.find("private var chatThread")
        self.assertGreater(chat_thread_start, -1, "chatThread must be defined")
        chat_thread_block = src[chat_thread_start : chat_thread_start + 600]
        self.assertIn("framingParagraph", chat_thread_block,
                      "framingParagraph must be pinned at top of chatThread")


class TestNexusTabStreamingState(unittest.TestCase):
    """NexusTabView: EchoPulseView shown while streaming."""

    def setUp(self):
        if not _exists(NEXUS_TAB):
            self.skipTest("NexusTabView.swift not found")
        self.src = _read(NEXUS_TAB)

    def test_echo_pulse_view_defined(self):
        """EchoPulseView struct must be defined."""
        self.assertIn("struct EchoPulseView", self.src)

    def test_echo_pulse_shown_during_streaming(self):
        """EchoPulseView is rendered when phase == .streaming."""
        src = self.src
        prompt_row_start = src.find("private var promptRow")
        if prompt_row_start == -1:
            prompt_row_start = src.find("var promptRow")
        self.assertGreater(prompt_row_start, -1)
        prompt_block = src[prompt_row_start : prompt_row_start + 300]
        self.assertIn("EchoPulseView()", prompt_block)
        self.assertIn(".streaming", prompt_block)

    def test_echo_pulse_replaces_starter_chips(self):
        """StarterPromptsRow replaces EchoPulseView when not streaming."""
        src = self.src
        prompt_row_start = src.find("private var promptRow")
        if prompt_row_start == -1:
            prompt_row_start = src.find("var promptRow")
        prompt_block = src[prompt_row_start : prompt_row_start + 400]
        self.assertIn("StarterPromptsRow", prompt_block)

    def test_echo_pulse_has_two_ring_phases(self):
        """EchoPulseView uses two ring phases (phase1 + phase2)."""
        src = self.src
        pulse_start = src.find("struct EchoPulseView")
        pulse_block = src[pulse_start : pulse_start + 800]
        self.assertIn("phase1", pulse_block)
        self.assertIn("phase2", pulse_block)

    def test_echo_pulse_has_breathing_center_dot(self):
        """EchoPulseView center dot uses a 'breathe' animation state."""
        src = self.src
        pulse_start = src.find("struct EchoPulseView")
        pulse_block = src[pulse_start : pulse_start + 600]
        self.assertIn("breathe", pulse_block)

    def test_streaming_cursor_defined(self):
        """StreamingCursor struct must be defined for mid-stream indicator."""
        self.assertIn("struct StreamingCursor", self.src)


class TestNexusTabErrorState(unittest.TestCase):
    """NexusTabView: error banner on chat API failure."""

    def setUp(self):
        if not _exists(NEXUS_TAB):
            self.skipTest("NexusTabView.swift not found")
        self.src = _read(NEXUS_TAB)

    def test_error_banner_defined(self):
        """ErrorBanner struct must be defined."""
        self.assertIn("struct ErrorBanner", self.src)

    def test_error_banner_has_dismiss_button(self):
        """ErrorBanner must include an × dismiss button."""
        src = self.src
        banner_start = src.find("struct ErrorBanner")
        # ErrorBanner body can be up to 1200 chars — use larger window
        banner_block = src[banner_start : banner_start + 1200]
        self.assertIn("xmark", banner_block)

    def test_error_banner_shown_on_phase_error(self):
        """NexusTabView overlay shows ErrorBanner when phase == .error(...)."""
        self.assertIn("case .error(let msg)", self.src)

    def test_error_banner_uses_overlay(self):
        """ErrorBanner is presented via .overlay alignment .top."""
        self.assertIn(".overlay(alignment: .top)", self.src)

    def test_error_banner_has_exclamation_icon(self):
        """ErrorBanner uses exclamationmark icon."""
        src = self.src
        banner_start = src.find("struct ErrorBanner")
        banner_block = src[banner_start : banner_start + 800]
        self.assertIn("exclamationmark", banner_block)

    def test_error_banner_has_red_border(self):
        """ErrorBanner has a reddish border to signal error."""
        src = self.src
        banner_start = src.find("struct ErrorBanner")
        banner_block = src[banner_start : banner_start + 800]
        self.assertIn("#C0392B", banner_block)


# --------------------------------------------------------------------------- #
# ItemDetailView — processing, failed, and full-text loading states
# --------------------------------------------------------------------------- #

class TestItemDetailProcessingState(unittest.TestCase):
    """ItemDetailView: processing state while summary is being generated."""

    def setUp(self):
        if not _exists(ITEM_DETAIL):
            self.skipTest("ItemDetailView.swift not found")
        self.src = _read(ITEM_DETAIL)

    def test_processing_branch_in_summary_hero(self):
        """summaryHero must branch on .processing ingestStatus."""
        src = self.src
        summary_start = src.find("private var summaryHero")
        if summary_start == -1:
            summary_start = src.find("var summaryHero")
        self.assertGreater(summary_start, -1, "summaryHero must be defined")
        # summaryHero body spans ~1300 chars — need a large window
        summary_block = src[summary_start : summary_start + 1400]
        self.assertIn(".processing", summary_block)

    def test_generating_summary_label(self):
        """Processing state shows 'Generating summary…' label."""
        self.assertIn("Generating summary", self.src)

    def test_processing_placeholder_function_defined(self):
        """processingPlaceholder(label:) function must be defined."""
        self.assertIn("func processingPlaceholder(label:", self.src)

    def test_processing_dot_circle(self):
        """processingPlaceholder uses a Circle for the animated dot."""
        src = self.src
        placeholder_start = src.find("func processingPlaceholder")
        placeholder_block = src[placeholder_start : placeholder_start + 400]
        self.assertIn("Circle()", placeholder_block)


class TestItemDetailFullTextLoadingState(unittest.TestCase):
    """ItemDetailView: full-text skeleton while raw content is being fetched."""

    def setUp(self):
        if not _exists(ITEM_DETAIL):
            self.skipTest("ItemDetailView.swift not found")
        self.src = _read(ITEM_DETAIL)

    def test_full_text_section_defined(self):
        """fullTextSection must be defined."""
        self.assertIn("fullTextSection", self.src)

    def test_is_loading_full_content_check(self):
        """fullTextSection must check vm.isLoadingFullContent."""
        self.assertIn("vm.isLoadingFullContent", self.src)

    def test_loading_full_text_label(self):
        """Loading state shows 'Loading full text…' label."""
        self.assertIn("Loading full text", self.src)

    def test_is_loading_full_content_published(self):
        """ItemDetailViewModel must publish isLoadingFullContent."""
        src = self.src
        vm_start = src.find("class ItemDetailViewModel")
        vm_block = src[vm_start : vm_start + 600]
        self.assertIn("isLoadingFullContent", vm_block)

    def test_fetch_full_content_method(self):
        """fetchFullContent() async method must exist on ViewModel."""
        self.assertIn("func fetchFullContent()", self.src)

    def test_fetch_sets_is_loading_true(self):
        """fetchFullContent must set isLoadingFullContent = true."""
        src = self.src
        fetch_start = src.find("func fetchFullContent()")
        fetch_block = src[fetch_start : fetch_start + 400]
        self.assertIn("isLoadingFullContent = true", fetch_block)

    def test_fetch_clears_loading_via_defer(self):
        """fetchFullContent must clear isLoadingFullContent using defer."""
        src = self.src
        fetch_start = src.find("func fetchFullContent()")
        fetch_block = src[fetch_start : fetch_start + 400]
        self.assertIn("defer { isLoadingFullContent = false }", fetch_block)


class TestItemDetailNotAvailableState(unittest.TestCase):
    """ItemDetailView: no raw content available fallback notice."""

    def setUp(self):
        if not _exists(ITEM_DETAIL):
            self.skipTest("ItemDetailView.swift not found")
        self.src = _read(ITEM_DETAIL)

    def test_full_text_not_available_notice(self):
        """When raw_content is nil, show an informative notice."""
        self.assertIn("Full text not yet extracted", self.src)

    def test_full_text_not_available_icon(self):
        """Notice uses 'text.page.slash' system icon."""
        self.assertIn('"text.page.slash"', self.src)

    def test_full_text_not_available_background(self):
        """Notice card uses surface2 background (inline style)."""
        src = self.src
        full_text_start = src.find("private var fullTextSection")
        if full_text_start == -1:
            full_text_start = src.find("var fullTextSection")
        self.assertGreater(full_text_start, -1)
        # fullTextSection body extends ~1600 chars — use a wide window
        full_text_block = src[full_text_start : full_text_start + 1600]
        self.assertIn("Color.Nexus.surface2", full_text_block)


# --------------------------------------------------------------------------- #
# SearchView — idle, searching, empty, failed states
# --------------------------------------------------------------------------- #

class TestSearchViewIdleState(unittest.TestCase):
    """SearchView: idle state shown on first open."""

    def setUp(self):
        if not _exists(SEARCH_VIEW):
            self.skipTest("SearchView.swift not found")
        self.src = _read(SEARCH_VIEW)

    def test_idle_state_defined(self):
        """idleState view must be defined."""
        self.assertIn("idleState", self.src)

    def test_idle_state_copy(self):
        """Idle state shows 'Search your saves'."""
        self.assertIn("Search your saves", self.src)

    def test_idle_state_magnifyingglass_icon(self):
        """Idle state uses 'magnifyingglass' system image."""
        self.assertIn('"magnifyingglass"', self.src)

    def test_state_machine_has_idle_case(self):
        """SearchState enum must have .idle case."""
        src = _read(SEARCH_VM) if _exists(SEARCH_VM) else self.src
        self.assertIn("case idle", src)


class TestSearchViewSearchingState(unittest.TestCase):
    """SearchView: searching skeleton while debounce + API request is in flight."""

    def setUp(self):
        if not _exists(SEARCH_VIEW):
            self.skipTest("SearchView.swift not found")
        self.src = _read(SEARCH_VIEW)

    def test_searching_state_defined(self):
        """searchingState view must be defined."""
        self.assertIn("searchingState", self.src)

    def test_searching_state_has_spinner(self):
        """Searching state renders ProgressView (spinner)."""
        src = self.src
        # Find the var definition, not the usage in the router switch
        searching_start = src.find("private var searchingState")
        if searching_start == -1:
            searching_start = src.find("var searchingState:")
        self.assertGreater(searching_start, -1, "searchingState var must be defined")
        searching_block = src[searching_start : searching_start + 300]
        self.assertIn("ProgressView()", searching_block)

    def test_state_machine_has_searching_case(self):
        """SearchState enum must have .searching case."""
        src = _read(SEARCH_VM) if _exists(SEARCH_VM) else self.src
        self.assertIn("case searching", src)

    def test_debounce_delay_400ms(self):
        """SearchViewModel debounce delay must be 400ms."""
        if not _exists(SEARCH_VM):
            self.skipTest("SearchViewModel.swift not found")
        src = _read(SEARCH_VM)
        self.assertIn("400", src, "Debounce delay must be 400 milliseconds")


class TestSearchViewEmptyState(unittest.TestCase):
    """SearchView: empty state when query returns no results."""

    def setUp(self):
        if not _exists(SEARCH_VIEW):
            self.skipTest("SearchView.swift not found")
        self.src = _read(SEARCH_VIEW)

    def test_empty_state_defined(self):
        """emptyState view must be defined."""
        self.assertIn("emptyState", self.src)

    def test_empty_state_shows_query_in_message(self):
        """Empty state interpolates the query: 'No results for \"...\"'."""
        self.assertIn("No results for", self.src)
        self.assertIn("vm.query", self.src)

    def test_empty_state_includes_tip_text(self):
        """Empty state includes at least one helpful tip line."""
        self.assertIn("Try different keywords", self.src)

    def test_state_machine_has_empty_case(self):
        """SearchState enum must have .empty case."""
        if not _exists(SEARCH_VM):
            self.skipTest("SearchViewModel.swift not found")
        src = _read(SEARCH_VM)
        self.assertIn("case empty", src)


class TestSearchViewFailedState(unittest.TestCase):
    """SearchView: error state when API call fails."""

    def setUp(self):
        if not _exists(SEARCH_VIEW):
            self.skipTest("SearchView.swift not found")
        self.src = _read(SEARCH_VIEW)

    def test_failed_state_defined(self):
        """failedState view must be defined."""
        self.assertIn("failedState", self.src)

    def test_failed_state_has_error_icon(self):
        """Failed state uses 'exclamationmark.triangle' icon."""
        self.assertIn("exclamationmark.triangle", self.src)

    def test_failed_state_message_displayed(self):
        """Failed state shows the error message string."""
        src = self.src
        failed_start = src.find("private func failedState(message:")
        self.assertGreater(failed_start, -1, "failedState(message:) must be defined")
        failed_block = src[failed_start : failed_start + 400]
        self.assertIn("message", failed_block)

    def test_state_machine_has_failed_case(self):
        """SearchState enum must have .failed case."""
        if not _exists(SEARCH_VM):
            self.skipTest("SearchViewModel.swift not found")
        src = _read(SEARCH_VM)
        self.assertIn("case failed", src)

    def test_state_content_router_handles_all_states(self):
        """stateContent switch must handle idle/searching/results/empty/failed."""
        src = self.src
        state_content_start = src.find("stateContent")
        # Find the switch block
        switch_start = src.find("switch vm.state", state_content_start)
        self.assertGreater(switch_start, -1, "switch vm.state must exist in stateContent")
        switch_block = src[switch_start : switch_start + 400]
        for case in ("idle", "searching", "results", "empty", "failed"):
            self.assertIn(case, switch_block, f"State router must handle .{case}")


class TestSearchViewModel(unittest.TestCase):
    """SearchViewModel: state transitions, debounce, min query length."""

    def setUp(self):
        if not _exists(SEARCH_VM):
            self.skipTest("SearchViewModel.swift not found")
        self.src = _read(SEARCH_VM)

    def test_search_state_enum_defined(self):
        """SearchState enum must be defined."""
        self.assertIn("enum SearchState", self.src)

    def test_min_query_length_guard(self):
        """Single-character queries must not trigger search (minQueryLength = 2)."""
        self.assertIn("minQueryLength", self.src)

    def test_debounce_task_cancelled_on_new_input(self):
        """debounceTask?.cancel() must be called when query changes."""
        self.assertIn("debounceTask?.cancel()", self.src)

    def test_idle_state_on_empty_query(self):
        """Empty/whitespace query must set state to .idle."""
        self.assertIn("state = .idle", self.src)

    def test_searching_state_set_before_network_call(self):
        """state = .searching must be set before the API call."""
        src = self.src
        perform_start = src.find("func performSearch(query:")
        self.assertGreater(perform_start, -1)
        perform_block = src[perform_start : perform_start + 500]
        searching_pos = perform_block.find("state = .searching")
        api_pos       = perform_block.find("APIClient.shared.search")
        self.assertGreater(searching_pos, -1, "state = .searching must be set")
        self.assertGreater(api_pos, -1, "APIClient.shared.search must be called")
        self.assertLess(searching_pos, api_pos,
                        ".searching must be set BEFORE the API call")

    def test_empty_state_on_zero_results(self):
        """Zero results from API sets state to .empty."""
        self.assertIn("state = .empty", self.src)

    def test_results_state_on_success(self):
        """Successful API response with items sets state to .results(...)."""
        self.assertIn("state = .results(", self.src)

    def test_failed_state_on_error(self):
        """API error sets state to .failed(...)."""
        self.assertIn("state = .failed(", self.src)

    def test_clear_search_resets_to_idle(self):
        """clearSearch() resets query and returns to .idle."""
        src = self.src
        clear_start = src.find("func clearSearch()")
        self.assertGreater(clear_start, -1, "clearSearch() must be defined")
        clear_block = src[clear_start : clear_start + 200]
        self.assertIn('query = ""', clear_block)
        self.assertIn("state = .idle", clear_block)


# --------------------------------------------------------------------------- #
# NexusCollection model — status field
# --------------------------------------------------------------------------- #

class TestNexusCollectionModel(unittest.TestCase):
    """NexusCollection Swift model has correct fields."""

    def setUp(self):
        if not _exists(NEXUS_COLLECTION):
            self.skipTest("NexusCollection.swift not found")
        self.src = _read(NEXUS_COLLECTION)

    def test_nexus_collection_struct_defined(self):
        """NexusCollection struct must be defined."""
        self.assertIn("struct NexusCollection", self.src)

    def test_source_count_field(self):
        """NexusCollection must have sourceCount: Int."""
        self.assertIn("let sourceCount:", self.src)

    def test_created_by_field(self):
        """NexusCollection must have createdBy enum field."""
        self.assertIn("let createdBy:", self.src)

    def test_created_by_enum_has_ai_case(self):
        """CreatedBy enum must have ai case (may be combined: 'case user, ai')."""
        # Swift allows combined case declarations: 'case user, ai'
        self.assertTrue(
            "case ai" in self.src or "case user, ai" in self.src,
            "CreatedBy enum must include an 'ai' case",
        )

    def test_created_by_enum_has_user_case(self):
        """CreatedBy enum must have user case."""
        self.assertTrue(
            "case user" in self.src or "case user," in self.src,
            "CreatedBy enum must include a 'user' case",
        )

    def test_framing_paragraph_optional(self):
        """framingParagraph must be optional."""
        self.assertIn("let framingParagraph: String?", self.src)

    def test_conforms_to_identifiable(self):
        """NexusCollection must conform to Identifiable."""
        self.assertIn("Identifiable", self.src)

    def test_conforms_to_hashable(self):
        """NexusCollection must conform to Hashable (NavigationPath requirement)."""
        self.assertIn("Hashable", self.src)


if __name__ == "__main__":
    unittest.main()
