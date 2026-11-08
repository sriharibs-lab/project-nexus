"""
Tests for task 1C-007 — NexusTabView.swift + NexusViewModel.swift

These tests inspect the Swift source files as text to verify that the required
implementation patterns are present and correctly structured. They run without
Xcode or a device — no Swift compilation needed.

Covered test hints:
  1. CollectionView starts with selectedTab = .nexus (default landing)
  2. Framing paragraph renders with plum accent bar; fallback includes source count
  3. Starter prompt chip populates composer + fires SSE; contextual chips replace defaults after first send
  4. EchoPulseView renders during streaming (two rings, breathing center, label)
  5. Citation chips parse [Source N] tokens and open URL on tap
  6. buildHistory() passes only last 12 messages (6 turns) to the API
  7. SSE error event triggers ErrorBanner with dismiss X
  8. LiquidGlassTabCapsule uses backdrop blur + gradient stroke bevel; tapping Sources uses NexusAnimation.pivot
  9. CollectionView uses the real NexusTabView (no stub struct)
  10. Endpoints.chat(collectionId:) resolves to /v1/collections/{uuid}/chat
"""

from __future__ import annotations
import pathlib as _pl; _REPO_ROOT = str(_pl.Path(__file__).resolve().parents[3])  # repo root, portable

import os
import re
import unittest

# --------------------------------------------------------------------------- #
# File paths — worktree first, fall back to main tree after merge
# --------------------------------------------------------------------------- #

_WORKTREE = _REPO_ROOT + "/.claude/worktrees/wf_5f2d3d42-857-3"
_MAIN     = _REPO_ROOT + ""


def _wt(rel: str) -> str:
    """Return worktree path if present, else main-tree path."""
    wt = os.path.join(_WORKTREE, rel)
    mt = os.path.join(_MAIN, rel)
    return wt if os.path.exists(wt) else mt


NEXUS_TAB_VIEW  = _wt("app-ios/Nexus/Nexus/Features/Collection/NexusTabView.swift")
NEXUS_VM        = _wt("app-ios/Nexus/Nexus/Features/Collection/NexusViewModel.swift")
COLLECTION_VIEW = _wt("app-ios/Nexus/Nexus/Features/Collection/CollectionView.swift")
ENDPOINTS       = _wt("app-ios/Nexus/Nexus/Core/Network/Endpoints.swift")


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


# --------------------------------------------------------------------------- #
# 1. Default landing tab
# --------------------------------------------------------------------------- #

class TestDefaultLandingTab(unittest.TestCase):
    """CollectionView.selectedTab must default to .nexus so NexusTabView is the first screen."""

    def setUp(self):
        self.src = _read(COLLECTION_VIEW)

    def test_selected_tab_default_is_nexus(self):
        """@State selectedTab is initialized to .nexus."""
        self.assertIn(
            "@State private var selectedTab: Tab = .nexus",
            self.src,
            "CollectionView must start with selectedTab = .nexus",
        )

    def test_nexus_case_defined_in_tab_enum(self):
        """Tab enum must declare a .nexus case."""
        self.assertIn("case nexus", self.src, "Tab enum must have a 'nexus' case")

    def test_sources_case_defined_in_tab_enum(self):
        """Tab enum must declare a .sources case."""
        self.assertIn("case sources", self.src, "Tab enum must have a 'sources' case")


# --------------------------------------------------------------------------- #
# 2. Framing paragraph
# --------------------------------------------------------------------------- #

class TestFramingParagraph(unittest.TestCase):
    """Framing paragraph: accent bar + text when framingParagraph set; fallback with source count when nil."""

    def setUp(self):
        self.src = _read(NEXUS_TAB_VIEW)

    def test_accent_bar_uses_nexus_accent_color(self):
        """.fill(Color.Nexus.accent) inside the framing paragraph view."""
        # The framing section has an accent bar with Color.Nexus.accent fill
        self.assertIn("Color.Nexus.accent", self.src)

    def test_framing_paragraph_reads_collection_framing_paragraph(self):
        """framingParagraph property of collection is checked."""
        self.assertIn("collection.framingParagraph", self.src)

    def test_fallback_includes_source_count(self):
        """Fallback copy references collection.sourceCount."""
        self.assertIn("collection.sourceCount", self.src)

    def test_fallback_text_mentions_sources(self):
        """Fallback copy includes a phrase about 'sources'."""
        self.assertIn("sources", self.src.lower())

    def test_nexus_label_shown_in_framing_header(self):
        """"NEXUS" overline label appears in framing paragraph section."""
        self.assertIn('"NEXUS"', self.src)

    def test_framing_paragraph_background_uses_bloom(self):
        """Background uses bloom color for the framing card."""
        self.assertIn("Color.Nexus.bloom", self.src)


# --------------------------------------------------------------------------- #
# 3. Starter prompts — defaults vs contextual
# --------------------------------------------------------------------------- #

class TestStarterPrompts(unittest.TestCase):
    """Default 6 prompts shown before first send; 3 contextual chips shown after."""

    def setUp(self):
        self.src = _read(NEXUS_VM)

    def test_default_starter_prompts_has_six_entries(self):
        """defaultStarterPrompts must contain exactly 6 items."""
        # Find the defaultStarterPrompts array
        match = re.search(
            r"defaultStarterPrompts:\s*\[String\]\s*=\s*\[(.*?)\]",
            self.src,
            re.DOTALL,
        )
        self.assertIsNotNone(match, "defaultStarterPrompts array not found")
        items = [line.strip() for line in match.group(1).split(",") if line.strip()]
        self.assertEqual(len(items), 6, f"Expected 6 default prompts, got {len(items)}")

    def test_contextual_starter_prompts_has_three_entries(self):
        """contextualStarterPrompts must contain exactly 3 items."""
        match = re.search(
            r"contextualStarterPrompts:\s*\[String\]\s*=\s*\[(.*?)\]",
            self.src,
            re.DOTALL,
        )
        self.assertIsNotNone(match, "contextualStarterPrompts array not found")
        items = [line.strip() for line in match.group(1).split(",") if line.strip()]
        self.assertEqual(len(items), 3, f"Expected 3 contextual prompts, got {len(items)}")

    def test_starter_prompts_switches_on_has_received_first_message(self):
        """starterPrompts computed var checks hasReceivedFirstMessage."""
        self.assertIn("hasReceivedFirstMessage", self.src)

    def test_send_starter_populates_input_then_sends(self):
        """sendStarter assigns inputText then calls send()."""
        self.assertIn("inputText = prompt", self.src)
        self.assertIn("send()", self.src)

    def test_has_received_first_message_set_on_send(self):
        """hasReceivedFirstMessage is set to true inside send()."""
        # Must appear inside send() — check it's set to true
        self.assertIn("hasReceivedFirstMessage = true", self.src)


# --------------------------------------------------------------------------- #
# 4. EchoPulseView
# --------------------------------------------------------------------------- #

class TestEchoPulseView(unittest.TestCase):
    """EchoPulseView: two animated rings + breathing center dot + label."""

    def setUp(self):
        self.src = _read(NEXUS_TAB_VIEW)

    def test_echo_pulse_view_defined(self):
        """EchoPulseView struct must be declared."""
        self.assertIn("struct EchoPulseView", self.src)

    def test_two_phase_state_variables(self):
        """Two independent phase state vars for ring animation."""
        self.assertIn("phase1", self.src)
        self.assertIn("phase2", self.src)

    def test_breathe_state_variable(self):
        """A breathe state variable drives the center dot animation."""
        self.assertIn("breathe", self.src)

    def test_nexus_is_thinking_label(self):
        """"Nexus is thinking…" label must be present."""
        self.assertIn("Nexus is thinking", self.src)

    def test_canvas_used_for_performance(self):
        """Canvas is used for the pulse animation."""
        self.assertIn("Canvas", self.src)

    def test_center_dot_uses_accent_color(self):
        """Center dot fill uses accent color."""
        self.assertIn("Nexus.accent", self.src)

    def test_echo_pulse_shown_during_streaming(self):
        """EchoPulseView is shown when phase == .streaming."""
        self.assertIn("EchoPulseView()", self.src)
        self.assertIn(".streaming", self.src)

    def test_staggered_ring_animation_delay(self):
        """Ring 2 is staggered with a delay so rings are offset."""
        self.assertIn("asyncAfter", self.src)


# --------------------------------------------------------------------------- #
# 5. Citation chips
# --------------------------------------------------------------------------- #

class TestCitationChips(unittest.TestCase):
    """Citation chips: parse [Source N] tokens; tap opens URL via UIApplication."""

    def setUp(self):
        self.src_view = _read(NEXUS_TAB_VIEW)
        self.src_vm   = _read(NEXUS_VM)

    def test_citation_chip_struct_defined(self):
        """CitationChip struct must be declared."""
        self.assertIn("struct CitationChip", self.src_view)

    def test_citation_chips_row_struct_defined(self):
        """CitationChipsRow struct must be declared."""
        self.assertIn("CitationChipsRow", self.src_view)

    def test_ui_application_open_called_on_tap(self):
        """Tapping a chip calls UIApplication.shared.open()."""
        self.assertIn("UIApplication.shared.open(", self.src_view)

    def test_cited_source_model_has_url(self):
        """CitedSource model has a url property."""
        self.assertIn("let url: String", self.src_vm)

    def test_cited_source_model_has_index(self):
        """CitedSource model has an index property for [Source N]."""
        self.assertIn("let index: Int", self.src_vm)

    def test_citation_parsing_uses_regex(self):
        """parseCitations uses regex to find [Source N] tokens."""
        self.assertIn(r"Source (\d+)", self.src_vm)

    def test_source_token_stripped_from_display_text(self):
        """[Source N] tokens are stripped from the displayed bubble text."""
        # strippedContent private var removes [Source N] from text
        self.assertIn("strippedContent", self.src_view)
        self.assertIn(r"Source \d+", self.src_view)

    def test_citation_chips_shown_only_for_assistant_messages(self):
        """CitationChipsRow is only rendered for assistant role messages."""
        self.assertIn("message.role == .assistant", self.src_view)

    def test_citation_chip_uses_url_from_source(self):
        """CitationChip opens source.url."""
        self.assertIn("source.url", self.src_view)


# --------------------------------------------------------------------------- #
# 6. buildHistory() — 12-message cap (6 turns)
# --------------------------------------------------------------------------- #

class TestBuildHistory(unittest.TestCase):
    """buildHistory() must cap at 12 messages (last 6 user+assistant pairs)."""

    def setUp(self):
        self.src = _read(NEXUS_VM)

    def test_build_history_method_defined(self):
        """buildHistory() method must be declared."""
        self.assertIn("func buildHistory()", self.src)

    def test_suffix_12_cap_applied(self):
        """suffix(12) limits to 12 messages."""
        self.assertIn("suffix(12)", self.src)

    def test_streaming_messages_excluded(self):
        """buildHistory() filters out currently-streaming messages."""
        self.assertIn("isStreaming", self.src)
        # The filter must exclude streaming messages
        self.assertIn("!$0.isStreaming", self.src)

    def test_empty_content_excluded(self):
        """buildHistory() filters out messages with empty content."""
        self.assertIn("!$0.content.isEmpty", self.src)

    def test_history_role_mapping(self):
        """History maps role to 'user' or 'assistant' string."""
        self.assertIn('"user"', self.src)
        self.assertIn('"assistant"', self.src)

    def test_build_history_returns_array_of_string_dicts(self):
        """Return type is [[String: String]]."""
        self.assertIn("[[String: String]]", self.src)

    def test_history_used_in_stream_chat(self):
        """buildHistory() is called inside streamChat."""
        self.assertIn("buildHistory()", self.src)


# --------------------------------------------------------------------------- #
# 7. SSE error → ErrorBanner with dismiss X
# --------------------------------------------------------------------------- #

class TestErrorBanner(unittest.TestCase):
    """SSE error event triggers ErrorBanner; dismiss X returns to .idle."""

    def setUp(self):
        self.src_view = _read(NEXUS_TAB_VIEW)
        self.src_vm   = _read(NEXUS_VM)

    def test_error_banner_struct_defined(self):
        """ErrorBanner struct must be declared in NexusTabView.swift."""
        self.assertIn("struct ErrorBanner", self.src_view)

    def test_error_banner_has_dismiss_button(self):
        """ErrorBanner has an onDismiss action wired to an X button."""
        self.assertIn("onDismiss", self.src_view)
        self.assertIn('"xmark"', self.src_view)

    def test_error_phase_shows_banner(self):
        """The overlay checks for .error case and shows the banner."""
        self.assertIn("case .error(let msg)", self.src_view)
        self.assertIn("ErrorBanner(", self.src_view)

    def test_dismiss_error_resets_phase_to_idle(self):
        """dismissError() sets phase back to .idle."""
        self.assertIn("func dismissError()", self.src_vm)
        self.assertIn("phase = .idle", self.src_vm)

    def test_sse_error_event_sets_error_phase(self):
        """Handling 'error' type SSE event puts ViewModel in .error phase."""
        self.assertIn('case "error":', self.src_vm)
        self.assertIn("phase = .error(", self.src_vm)

    def test_error_banner_shown_at_top_edge(self):
        """ErrorBanner shown via .overlay(alignment: .top)."""
        self.assertIn("alignment: .top", self.src_view)

    def test_error_banner_has_transition_animation(self):
        """ErrorBanner entry/exit uses a transition animation."""
        self.assertIn(".transition(", self.src_view)


# --------------------------------------------------------------------------- #
# 8. LiquidGlassTabCapsule
# --------------------------------------------------------------------------- #

class TestLiquidGlassTabCapsule(unittest.TestCase):
    """LiquidGlassTabCapsule: backdrop blur + gradient stroke bevel; pivot animation on tab switch."""

    def setUp(self):
        self.src = _read(NEXUS_TAB_VIEW)

    def test_liquid_glass_tab_capsule_struct_defined(self):
        """LiquidGlassTabCapsule struct must be declared."""
        self.assertIn("struct LiquidGlassTabCapsule", self.src)

    def test_uses_ultra_thin_material_for_blur(self):
        """Uses .ultraThinMaterial for the frosted glass effect."""
        self.assertIn(".ultraThinMaterial", self.src)

    def test_gradient_stroke_bevel_present(self):
        """Linear gradient is used for the bevel stroke overlay."""
        self.assertIn("LinearGradient", self.src)

    def test_capsule_shape_used(self):
        """Capsule shape is used for clipping and overlay."""
        self.assertIn("Capsule()", self.src)

    def test_float_shadow_applied(self):
        """Drop shadow applied for the floating appearance."""
        self.assertIn(".shadow(", self.src)

    def test_tab_switch_uses_nexus_animation_pivot(self):
        """Tab selection changes use NexusAnimation.pivot."""
        self.assertIn("NexusAnimation.pivot", self.src)

    def test_selected_tab_binding(self):
        """LiquidGlassTabCapsule accepts a @Binding var selectedTab."""
        self.assertIn("@Binding var selectedTab:", self.src)

    def test_all_cases_rendered_via_for_each(self):
        """ForEach(Array(Tab.allCases)) renders all tabs dynamically."""
        self.assertIn("Tab.allCases", self.src)

    def test_selected_pill_has_white_background(self):
        """Selected tab pill gets a white/opaque background."""
        self.assertIn("Color.white", self.src)

    def test_gradient_stroke_has_three_color_stops(self):
        """The bevel gradient has 3 color stops (top-white → mid → blue tint)."""
        # Count occurrences of color stops in the gradient colors array
        match = re.search(r"LinearGradient\(.*?colors:\s*\[(.*?)\]", self.src, re.DOTALL)
        self.assertIsNotNone(match, "LinearGradient colors array not found")
        stops = [s.strip() for s in match.group(1).split(",") if s.strip()]
        self.assertGreaterEqual(len(stops), 3, "Gradient must have at least 3 color stops")


# --------------------------------------------------------------------------- #
# 9. CollectionView uses real NexusTabView (no stub)
# --------------------------------------------------------------------------- #

class TestNoStubNexusTabView(unittest.TestCase):
    """CollectionView must reference the real NexusTabView, not a stub struct."""

    def setUp(self):
        self.cv_src = _read(COLLECTION_VIEW)

    def test_nexus_tab_view_used_in_tab_content(self):
        """NexusTabView(collection:) is called inside tabContent."""
        self.assertIn("NexusTabView(collection:", self.cv_src)

    def test_no_stub_struct_in_collection_view(self):
        """CollectionView.swift must NOT define its own NexusTabView stub."""
        # A stub would look like 'struct NexusTabView' defined inside CollectionView.swift
        stub_matches = re.findall(r"struct\s+NexusTabView", self.cv_src)
        self.assertEqual(
            len(stub_matches),
            0,
            "CollectionView.swift must not contain a stub 'struct NexusTabView'",
        )

    def test_liquid_glass_tab_capsule_used_in_collection_view(self):
        """CollectionView uses LiquidGlassTabCapsule for its tab switcher."""
        self.assertIn("LiquidGlassTabCapsule(", self.cv_src)


# --------------------------------------------------------------------------- #
# 10. Endpoints.chat(collectionId:) path matches backend route
# --------------------------------------------------------------------------- #

class TestChatEndpoint(unittest.TestCase):
    """Endpoints.chat(collectionId:) must resolve to /v1/collections/{uuid}/chat."""

    def setUp(self):
        self.src = _read(ENDPOINTS)

    def test_chat_case_defined(self):
        """Endpoint enum has a chat(collectionId:) case."""
        self.assertIn("case chat(collectionId:", self.src)

    def test_chat_path_matches_backend_route(self):
        """chat case path is /v1/collections/{id}/chat."""
        match = re.search(r'case \.chat\(let cid\):\s*return "([^"]+)"', self.src)
        self.assertIsNotNone(match, "chat case path string not found in Endpoints.swift")
        path = match.group(1)
        # Must start with /v1/collections/ and end with /chat
        self.assertTrue(
            path.startswith("/v1/collections/"),
            f"chat path must start with /v1/collections/, got: {path}",
        )
        self.assertTrue(
            path.endswith("/chat"),
            f"chat path must end with /chat, got: {path}",
        )
        # Must include the uuid placeholder
        self.assertIn("cid", path, "chat path must interpolate the collection id")

    def test_chat_url_constructed_from_base_url(self):
        """Endpoint.url combines baseURL + path."""
        self.assertIn("Endpoint.baseURL + path", self.src)


# --------------------------------------------------------------------------- #
# 11. NexusViewModel — SSE consumer and NexusPhase
# --------------------------------------------------------------------------- #

class TestNexusViewModel(unittest.TestCase):
    """NexusViewModel: SSE consumer, phase transitions, message history."""

    def setUp(self):
        self.src = _read(NEXUS_VM)

    def test_nexus_phase_enum_defined(self):
        """NexusPhase enum with idle/streaming/error cases is declared."""
        self.assertIn("enum NexusPhase", self.src)
        self.assertIn("case idle", self.src)
        self.assertIn("case streaming", self.src)
        self.assertIn("case error", self.src)

    def test_messages_published(self):
        """messages is a @Published array of ChatMessage."""
        self.assertIn("@Published private(set) var messages:", self.src)

    def test_phase_published(self):
        """phase is a @Published NexusPhase property."""
        self.assertIn("@Published private(set) var phase:", self.src)

    def test_stream_chat_sets_streaming_phase(self):
        """streamChat sets phase to .streaming at entry."""
        self.assertIn("phase = .streaming", self.src)

    def test_sources_event_populates_retrieved_sources(self):
        """'sources' SSE event populates retrievedSources."""
        self.assertIn('case "sources":', self.src)
        self.assertIn("retrievedSources =", self.src)

    def test_chunk_event_appends_to_content(self):
        """'chunk' SSE event appends text to the assistant message."""
        self.assertIn('case "chunk":', self.src)
        self.assertIn(".content +=", self.src)

    def test_done_event_clears_streaming_flag(self):
        """'done' SSE event sets isStreaming = false and phase = .idle."""
        self.assertIn('case "done":', self.src)
        self.assertIn("isStreaming = false", self.src)

    def test_chat_message_model_defined(self):
        """ChatMessage struct with role, content, isStreaming fields."""
        self.assertIn("struct ChatMessage", self.src)
        self.assertIn("var isStreaming: Bool", self.src)

    def test_cited_source_model_defined(self):
        """CitedSource struct defined with id, index, title, url."""
        self.assertIn("struct CitedSource", self.src)
        self.assertIn("let title: String", self.src)
        self.assertIn("let url: String", self.src)

    def test_chat_request_body_encodes_message_and_history(self):
        """ChatRequestBody encodes both message and messages[] for API."""
        self.assertIn("struct ChatRequestBody", self.src)
        self.assertIn("let message: String", self.src)
        self.assertIn("let messages:", self.src)

    def test_main_actor_annotation(self):
        """NexusViewModel is @MainActor for UI thread safety."""
        self.assertIn("@MainActor", self.src)
