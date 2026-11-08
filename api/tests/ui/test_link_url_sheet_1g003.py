"""
Tests for task 1G-003 — URL content-type auto-detect in LinkURLSheetView.

Parses Swift source files as text and validates:
- detectContentType logic for youtube.com, youtu.be, .pdf extension, generic URLs, unparseable input
- DetectedContentType enum labels, icons, backendString, colors
- Sheet structural elements: chip row, URL field, canSubmit guard, collection picker
- CollectionView: '+' toolbar only on Sources tab, sheet pre-scoped to collection
- ResearchFlowView: FRELinkButtons passes correct DetectedContentType to sheet
- FRELinkButtons: lists Website, PDF, YouTube

No iOS simulator required — plain Python text inspection.
"""

from __future__ import annotations
import pathlib as _pl; _REPO_ROOT = str(_pl.Path(__file__).resolve().parents[3])  # repo root, portable

import os
import re
import unittest

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

_WORKTREE = _REPO_ROOT + "/.claude/worktrees/wf_5a6a2270-719-6"
_MAIN     = _REPO_ROOT + ""

def _wt(rel: str) -> str:
    """Return worktree path when present, else fall back to main tree."""
    wt = os.path.join(_WORKTREE, rel)
    mt = os.path.join(_MAIN, rel)
    return wt if os.path.exists(wt) else mt


LINK_SHEET_PATH    = _wt("app-ios/Nexus/Nexus/Features/Collection/LinkURLSheetView.swift")
COLLECTION_VIEW    = _wt("app-ios/Nexus/Nexus/Features/Collection/CollectionView.swift")
RESEARCH_FLOW      = _wt("app-ios/Nexus/Nexus/Features/Research/ResearchFlowView.swift")


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


# ---------------------------------------------------------------------------
# 1. File existence
# ---------------------------------------------------------------------------

class TestFileExistence(unittest.TestCase):
    """All three key files must be present (created or modified by SWE)."""

    def test_link_url_sheet_view_exists(self):
        self.assertTrue(os.path.exists(LINK_SHEET_PATH),
                        f"LinkURLSheetView.swift not found at {LINK_SHEET_PATH}")

    def test_collection_view_exists(self):
        self.assertTrue(os.path.exists(COLLECTION_VIEW),
                        f"CollectionView.swift not found at {COLLECTION_VIEW}")

    def test_research_flow_view_exists(self):
        self.assertTrue(os.path.exists(RESEARCH_FLOW),
                        f"ResearchFlowView.swift not found at {RESEARCH_FLOW}")


# ---------------------------------------------------------------------------
# 2. DetectedContentType enum
# ---------------------------------------------------------------------------

class TestDetectedContentTypeEnum(unittest.TestCase):
    """DetectedContentType must declare the three required cases with correct metadata."""

    def setUp(self):
        self.src = _read(LINK_SHEET_PATH)

    def test_enum_declared(self):
        self.assertIn("enum DetectedContentType", self.src)

    def test_all_three_cases_declared(self):
        """All three content type cases must be present."""
        for case in ("case youtube", "case pdf", "case website"):
            self.assertIn(case, self.src, f"Missing: {case}")

    def test_labels_correct(self):
        """Human-readable labels: YouTube, PDF, Website."""
        self.assertIn('"YouTube"', self.src)
        self.assertIn('"PDF"', self.src)
        self.assertIn('"Website"', self.src)

    def test_icons_correct(self):
        """SF Symbol names for the chip icons."""
        self.assertIn('"play.rectangle.fill"', self.src)
        self.assertIn('"doc.fill"', self.src)
        self.assertIn('"globe"', self.src)

    def test_backend_strings_correct(self):
        """backendString values sent to the ingest API."""
        self.assertIn('"youtube"', self.src)
        self.assertIn('"pdf"', self.src)
        self.assertIn('"article"', self.src)

    def test_youtube_foreground_warm_red(self):
        """YouTube chip uses warm red accent #B84C3A."""
        self.assertIn("#B84C3A", self.src)

    def test_pdf_foreground_cool_blue(self):
        """PDF chip uses cool blue #4A7ABB."""
        self.assertIn("#4A7ABB", self.src)

    def test_website_foreground_sage_green(self):
        """Website chip uses sage green #4A8A5C."""
        self.assertIn("#4A8A5C", self.src)

    def test_identifiable_conformance(self):
        """DetectedContentType must conform to Identifiable for .sheet(item:) usage."""
        self.assertIn("Identifiable", self.src)
        # id property backed by rawValue
        self.assertIn("var id:", self.src)
        self.assertIn("rawValue", self.src)


# ---------------------------------------------------------------------------
# 3. detectContentType pure function
# ---------------------------------------------------------------------------

class TestDetectContentTypeFunction(unittest.TestCase):
    """
    Validate that the detection function encodes the correct heuristics
    by inspecting the Swift source text for the expected rule fragments.
    """

    def setUp(self):
        self.src = _read(LINK_SHEET_PATH)

    def test_function_declared(self):
        self.assertIn("func detectContentType(from rawURL: String)", self.src)

    def test_youtube_com_rule(self):
        """Must check for youtube.com host."""
        self.assertIn('"youtube.com"', self.src)

    def test_youtu_be_rule(self):
        """Must check for youtu.be host (short-link form)."""
        self.assertIn('"youtu.be"', self.src)

    def test_pdf_extension_rule(self):
        """Must check path suffix .pdf."""
        self.assertIn('".pdf"', self.src)

    def test_https_prepend_for_bare_hosts(self):
        """Bare URLs without a scheme must be prefixed with https:// before parsing."""
        self.assertIn('"https://"', self.src)

    def test_returns_nil_for_unparseable(self):
        """Unparseable URLs must return nil (chip hidden, canSubmit false)."""
        # The function must guard URL parsing and return nil
        self.assertIn("return nil", self.src)

    def test_host_nil_check(self):
        """Must verify url.host is non-nil to reject bare garbage strings."""
        self.assertIn("url.host", self.src)

    def test_website_fallback(self):
        """Must return .website as the final fallback for any parseable URL."""
        self.assertIn("return .website", self.src)

    def test_host_lowercased(self):
        """Host comparison must be case-insensitive (lowercased)."""
        self.assertIn(".lowercased()", self.src)


# ---------------------------------------------------------------------------
# 4. LinkURLSheetView structure
# ---------------------------------------------------------------------------

class TestLinkURLSheetViewStructure(unittest.TestCase):
    """LinkURLSheetView: struct, required properties, and key UI patterns."""

    def setUp(self):
        self.src = _read(LINK_SHEET_PATH)

    def test_struct_declared(self):
        self.assertIn("struct LinkURLSheetView: View", self.src)

    def test_initial_content_type_param(self):
        """initialContentType parameter must be present."""
        self.assertIn("initialContentType: DetectedContentType", self.src)

    def test_collections_param(self):
        """collections parameter must accept an array."""
        self.assertIn("collections: [NexusCollection]", self.src)

    def test_preselected_collection_id_param(self):
        """preselectedCollectionId optional parameter must be present."""
        self.assertIn("preselectedCollectionId", self.src)

    def test_on_complete_callback(self):
        """onComplete callback must carry jobId and collectionId."""
        self.assertIn("onComplete:", self.src)
        self.assertIn("jobId", self.src)
        self.assertIn("collectionId", self.src)

    def test_url_text_state(self):
        """@State urlText must drive the text field."""
        self.assertIn("var urlText: String", self.src)

    def test_detected_type_state(self):
        """@State detectedType must hold the auto-detected type."""
        self.assertIn("var detectedType: DetectedContentType?", self.src)

    def test_on_change_wired(self):
        """onChange(of: urlText) must call detectContentType."""
        self.assertIn("onChange(of: urlText)", self.src)
        self.assertIn("detectContentType(from:", self.src)

    def test_can_submit_guards_detected_type(self):
        """canSubmit must be false when detectedType is nil."""
        self.assertIn("detectedType != nil", self.src)

    def test_can_submit_guards_collection(self):
        """canSubmit must require a non-nil effectiveCollectionId."""
        self.assertIn("effectiveCollectionId != nil", self.src)

    def test_effective_collection_id_logic(self):
        """effectiveCollectionId should prefer preselectedCollectionId."""
        self.assertIn("preselectedCollectionId ?? selectedCollectionId", self.src)

    def test_keyboard_delay_045s(self):
        """Keyboard focus must be delayed by 0.45 s to let sheet animation complete."""
        self.assertIn("0.45", self.src)
        self.assertIn("urlFocused = true", self.src)

    def test_content_type_chip_row_present(self):
        """The 'Detected as' chip row must appear in the layout."""
        self.assertIn('"Detected as"', self.src)

    def test_placeholder_dash_for_nil_type(self):
        """When detectedType is nil show a '–' placeholder."""
        self.assertIn('"–"', self.src)

    def test_save_button_uses_resolved_type_label(self):
        """CTA shows 'Save <type>' with the resolved type label."""
        self.assertIn('"Save \\(resolvedType.label)"', self.src)

    def test_backend_string_sent_to_ingest(self):
        """submit() must pass resolvedType.backendString as contentType."""
        self.assertIn("resolvedType.backendString", self.src)

    def test_collection_picker_hidden_when_preselected(self):
        """Collection picker must be hidden when preselectedCollectionId is set."""
        self.assertIn("preselectedCollectionId == nil", self.src)

    def test_content_type_chip_struct_declared(self):
        """ContentTypeChip private struct must exist."""
        self.assertIn("struct ContentTypeChip", self.src)

    def test_collection_chip_struct_declared(self):
        """CollectionChip private struct must exist."""
        self.assertIn("struct CollectionChip", self.src)

    def test_error_banner_struct_declared(self):
        """ErrorInlineBanner private struct must exist."""
        self.assertIn("struct ErrorInlineBanner", self.src)

    def test_submit_error_state(self):
        """submitError @State must hold API error messages."""
        self.assertIn("var submitError: String?", self.src)


# ---------------------------------------------------------------------------
# 5. CollectionView — '+' toolbar and sheet wiring
# ---------------------------------------------------------------------------

class TestCollectionViewPlusButton(unittest.TestCase):
    """'+' toolbar button appears only on the Sources tab and opens the sheet."""

    def setUp(self):
        self.src = _read(COLLECTION_VIEW)

    def test_link_sheet_content_type_state(self):
        """CollectionView must hold linkSheetContentType state."""
        self.assertIn("linkSheetContentType: DetectedContentType?", self.src)

    def test_plus_button_only_on_sources_tab(self):
        """The toolbar plus button must be guarded to the .sources tab."""
        self.assertIn("selectedTab == .sources", self.src)
        self.assertIn('"plus"', self.src)

    def test_sheet_item_linksheet_content_type(self):
        """CollectionView must present LinkURLSheetView via .sheet(item:)."""
        self.assertIn(".sheet(item: $linkSheetContentType)", self.src)

    def test_link_sheet_initial_content_type_website(self):
        """When '+' is tapped from the Sources tab, initialContentType is .website."""
        self.assertIn("linkSheetContentType = .website", self.src)

    def test_link_sheet_prescoped_to_collection(self):
        """Sheet must be pre-scoped: preselectedCollectionId: vm.collection.id."""
        self.assertIn("preselectedCollectionId: vm.collection.id", self.src)

    def test_on_complete_calls_vm_load(self):
        """onComplete must refresh the sources list via vm.load()."""
        self.assertIn("vm.load()", self.src)

    def test_nexus_tab_has_no_plus_button(self):
        """'+' must NOT appear when the Nexus tab is active."""
        # The guard must specifically check for .sources
        # Ensure the plus button is inside the selectedTab == .sources guard.
        src = self.src
        sources_guard_idx = src.find("selectedTab == .sources")
        plus_idx = src.find('"plus"')
        self.assertGreater(plus_idx, sources_guard_idx,
            '"plus" icon must appear inside the selectedTab == .sources guard')


# ---------------------------------------------------------------------------
# 6. ResearchFlowView — FRELinkButtons and sheet wiring
# ---------------------------------------------------------------------------

class TestResearchFlowViewLinkSheet(unittest.TestCase):
    """FRELinkButtons passes DetectedContentType to the sheet in ResearchFlowView."""

    def setUp(self):
        self.src = _read(RESEARCH_FLOW)

    def test_fre_link_buttons_struct_declared(self):
        """FRELinkButtons must be declared in ResearchFlowView.swift."""
        self.assertIn("struct FRELinkButtons", self.src)

    def test_fre_link_buttons_passes_detected_type(self):
        """FRELinkButtons callback must use DetectedContentType."""
        self.assertIn("DetectedContentType", self.src)

    def test_fre_link_buttons_three_options(self):
        """FRELinkButtons must list Website, PDF, and YouTube options."""
        for label in ('"Website"', '"PDF"', '"YouTube"'):
            self.assertIn(label, self.src, f"FRELinkButtons missing option: {label}")

    def test_fre_link_buttons_content_types(self):
        """FRELinkButtons options must reference all three DetectedContentType cases."""
        for ct in (".website", ".pdf", ".youtube"):
            self.assertIn(ct, self.src, f"FRELinkButtons missing content type: {ct}")

    def test_link_sheet_content_type_state_in_fre(self):
        """FREInputScreen must hold linkSheetContentType state."""
        self.assertIn("linkSheetContentType: DetectedContentType?", self.src)

    def test_fre_presents_link_url_sheet_view(self):
        """ResearchFlowView must present LinkURLSheetView from FREInputScreen."""
        self.assertIn("LinkURLSheetView(", self.src)

    def test_fre_sheet_uses_item_binding(self):
        """Sheet must be presented via .sheet(item: $linkSheetContentType)."""
        self.assertIn(".sheet(item: $linkSheetContentType)", self.src)

    def test_fre_sheet_no_preselected_collection(self):
        """FRE sheet must pass collections: [] (no collection context yet)."""
        self.assertIn("collections: []", self.src)

    def test_fre_link_buttons_on_select_sets_state(self):
        """FRELinkButtons onSelect callback must set linkSheetContentType."""
        self.assertIn("linkSheetContentType = contentType", self.src)

    def test_fre_sheet_large_detent(self):
        """Sheet in FRE must use .large presentation detent."""
        self.assertIn(".large", self.src)


# ---------------------------------------------------------------------------
# 7. Backend content-type strings (schema correctness)
# ---------------------------------------------------------------------------

class TestBackendContentTypeStrings(unittest.TestCase):
    """
    Verify the backendString mapping matches the API schema:
      youtube → "youtube"
      pdf     → "pdf"
      website → "article"
    """

    def setUp(self):
        self.src = _read(LINK_SHEET_PATH)

    def _extract_backend_string_block(self) -> str:
        """Extract the backendString computed property block."""
        m = re.search(
            r"var backendString.*?(?=\n\s{4}var |\n\s{4}//|\Z)",
            self.src,
            re.DOTALL,
        )
        return m.group(0) if m else ""

    def test_youtube_maps_to_youtube(self):
        """DetectedContentType.youtube → backendString "youtube"."""
        block = self._extract_backend_string_block()
        # Swift uses `case .youtube: return "youtube"`
        self.assertRegex(block, r'case\s+\.youtube.*?return\s+"youtube"')

    def test_pdf_maps_to_pdf(self):
        """DetectedContentType.pdf → backendString "pdf"."""
        block = self._extract_backend_string_block()
        self.assertRegex(block, r'case\s+\.pdf.*?return\s+"pdf"')

    def test_website_maps_to_article(self):
        """DetectedContentType.website → backendString "article" (not "website")."""
        block = self._extract_backend_string_block()
        self.assertRegex(block, r'case\s+\.website.*?return\s+"article"')


if __name__ == "__main__":
    unittest.main()
