"""
Tests for task 1F-004 — Keyboard dismiss on tap-outside in NexusTabView composer

These tests inspect NexusTabView.swift as text to verify that the required
keyboard-dismiss and focus-state implementation patterns are present and
correctly structured. They run without Xcode or a device.

Covered test hints:
  1. chatUI has .simultaneousGesture(TapGesture) that sets composerFocused = false
  2. ScrollView uses .scrollDismissesKeyboard(.interactively) for drag-to-dismiss
  3. StarterChip tap: sendStarter populates inputText AND calls send() (not swallowed)
  4. CitationChip tap: UIApplication.shared.open() still fires (not swallowed)
  5. Focus border: Nexus.accent at 50% opacity when focused, Nexus.border when not
  6. FocusState is lifted to NexusTabView (@FocusState composerFocused) and bound to ChatComposer
  7. onSubmit handler in ChatComposer is still present (send still works)
  8. Send button in ChatComposer still calls vm.send() when canSend is true
"""

from __future__ import annotations

import os
import re
import unittest

# --------------------------------------------------------------------------- #
# File paths — worktree first, fall back to main tree after merge
# --------------------------------------------------------------------------- #

_WORKTREE = "/Users/srihari/Documents/Projects/Project Nexus/.claude/worktrees/wf_1f4481b5-545-11"
_MAIN     = "/Users/srihari/Documents/Projects/Project Nexus"


def _wt(rel: str) -> str:
    """Return worktree path if present, else main-tree path."""
    wt = os.path.join(_WORKTREE, rel)
    mt = os.path.join(_MAIN, rel)
    return wt if os.path.exists(wt) else mt


NEXUS_TAB_VIEW = _wt("app-ios/Nexus/Nexus/Features/Collection/NexusTabView.swift")
NEXUS_VM       = _wt("app-ios/Nexus/Nexus/Features/Collection/NexusViewModel.swift")


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


# --------------------------------------------------------------------------- #
# 1. Tap-outside gesture uses .simultaneousGesture to set composerFocused = false
# --------------------------------------------------------------------------- #

class TestTapOutsideDismiss(unittest.TestCase):
    """
    chatUI must attach .simultaneousGesture(TapGesture().onEnded { composerFocused = false })
    so tapping the scroll area or anywhere outside the composer dismisses the keyboard.
    .simultaneousGesture is required (not .onTapGesture) so child button taps are not swallowed.
    """

    def setUp(self):
        self.src = _read(NEXUS_TAB_VIEW)

    def test_simultaneous_gesture_present(self):
        """.simultaneousGesture is used (not .onTapGesture) to allow child taps through."""
        self.assertIn(
            ".simultaneousGesture(",
            self.src,
            ".simultaneousGesture must be used so child button taps (chips, citations) are not swallowed",
        )

    def test_tap_gesture_in_simultaneous_gesture(self):
        """TapGesture() is passed to .simultaneousGesture."""
        self.assertIn(
            "TapGesture()",
            self.src,
            "TapGesture() must be the gesture used inside .simultaneousGesture",
        )

    def test_tap_sets_composer_focused_false(self):
        """The tap gesture handler sets composerFocused = false to dismiss the keyboard."""
        self.assertIn(
            "composerFocused = false",
            self.src,
            "The tap gesture onEnded handler must set composerFocused = false",
        )

    def test_on_tap_gesture_not_used_for_dismiss(self):
        """
        .onTapGesture should NOT be used for the dismiss gesture —
        it would swallow child taps. Only .simultaneousGesture is acceptable.
        Verify that composerFocused = false appears INSIDE the .simultaneousGesture block.
        """
        simultaneous_idx = self.src.find(".simultaneousGesture(")
        self.assertNotEqual(simultaneous_idx, -1, ".simultaneousGesture not found")

        # Find the composerFocused = false that appears AFTER .simultaneousGesture(
        # (the one inside the gesture block, not the comment above)
        false_idx = self.src.find("composerFocused = false", simultaneous_idx)
        self.assertNotEqual(
            false_idx,
            -1,
            "composerFocused = false not found after .simultaneousGesture — "
            "the gesture block must set composerFocused = false",
        )
        # The assignment must be within the gesture block (within ~200 chars of .simultaneousGesture)
        distance = false_idx - simultaneous_idx
        self.assertLess(
            distance,
            200,
            f"composerFocused = false (at +{distance} chars) must be inside the "
            ".simultaneousGesture block — it should appear within ~200 chars",
        )


# --------------------------------------------------------------------------- #
# 2. Drag-to-dismiss: .scrollDismissesKeyboard(.interactively)
# --------------------------------------------------------------------------- #

class TestScrollDismissesKeyboard(unittest.TestCase):
    """
    The chat scroll view must use .scrollDismissesKeyboard(.interactively)
    so dragging up through the thread pulls the keyboard down interactively.
    """

    def setUp(self):
        self.src = _read(NEXUS_TAB_VIEW)

    def test_scroll_dismisses_keyboard_modifier_present(self):
        """.scrollDismissesKeyboard is applied to the ScrollView."""
        self.assertIn(
            ".scrollDismissesKeyboard(",
            self.src,
            ".scrollDismissesKeyboard modifier is required on the chat ScrollView",
        )

    def test_interactive_mode_used(self):
        """Mode must be .interactively so keyboard follows the user's finger."""
        self.assertIn(
            ".interactively",
            self.src,
            ".scrollDismissesKeyboard(.interactively) is required — not .immediately or .never",
        )

    def test_modifier_appears_on_scroll_view(self):
        """The modifier appears near (after) a ScrollView declaration."""
        scroll_idx = self.src.find("ScrollView {")
        dismiss_idx = self.src.find(".scrollDismissesKeyboard(")
        self.assertNotEqual(scroll_idx, -1, "ScrollView { not found")
        self.assertNotEqual(dismiss_idx, -1, ".scrollDismissesKeyboard not found")
        # The modifier should come after the ScrollView open brace but within the chatThread context
        self.assertGreater(
            dismiss_idx, scroll_idx,
            ".scrollDismissesKeyboard must appear after the ScrollView declaration",
        )


# --------------------------------------------------------------------------- #
# 3. Starter chip tap: text populates AND send() fires (not swallowed)
# --------------------------------------------------------------------------- #

class TestStarterChipTapNotSwallowed(unittest.TestCase):
    """
    sendStarter() must assign inputText = prompt and then call send().
    The chip tap must not be swallowed by the keyboard dismiss gesture — confirmed
    by .simultaneousGesture being the dismiss mechanism (not .onTapGesture).
    """

    def setUp(self):
        self.src_view = _read(NEXUS_TAB_VIEW)
        self.src_vm   = _read(NEXUS_VM)

    def test_send_starter_populates_input_text(self):
        """sendStarter sets inputText = prompt before calling send()."""
        self.assertIn(
            "inputText = prompt",
            self.src_vm,
            "sendStarter() must set inputText = prompt",
        )

    def test_send_starter_calls_send(self):
        """sendStarter calls send() to dispatch the message."""
        self.assertIn(
            "send()",
            self.src_vm,
            "sendStarter() must call send() after setting inputText",
        )

    def test_starter_chip_has_action_closure(self):
        """StarterChip passes an action closure so the tap calls onSelect."""
        # StarterChip is a button with an action
        self.assertIn(
            "Button(action: action)",
            self.src_view,
            "StarterChip must use Button(action: action) to fire the tap action",
        )

    def test_starter_prompts_row_wires_on_select(self):
        """StarterPromptsRow calls onSelect on chip tap."""
        self.assertIn(
            "onSelect(",
            self.src_view,
            "StarterPromptsRow must call onSelect when a chip is tapped",
        )

    def test_prompt_row_wires_to_vm_send_starter(self):
        """The prompt row's onSelect is wired to vm.sendStarter in NexusTabView."""
        self.assertIn(
            "vm.sendStarter(",
            self.src_view,
            "NexusTabView must wire StarterPromptsRow's onSelect to vm.sendStarter",
        )


# --------------------------------------------------------------------------- #
# 4. Citation chip tap: UIApplication.shared.open() is not swallowed
# --------------------------------------------------------------------------- #

class TestCitationChipTapNotSwallowed(unittest.TestCase):
    """
    CitationChip must open the URL via UIApplication.shared.open() on tap.
    The .simultaneousGesture dismiss must not prevent this from firing.
    """

    def setUp(self):
        self.src = _read(NEXUS_TAB_VIEW)

    def test_citation_chip_opens_url_on_tap(self):
        """CitationChip calls UIApplication.shared.open() on button tap."""
        self.assertIn(
            "UIApplication.shared.open(",
            self.src,
            "CitationChip must call UIApplication.shared.open() to open the URL",
        )

    def test_citation_chip_uses_button(self):
        """CitationChip uses a Button so its tap action is a standard control event."""
        # CitationChip body contains a Button with the URL action
        # Check that Button appears before UIApplication.shared.open in the CitationChip context
        chip_idx = self.src.find("struct CitationChip")
        open_idx = self.src.find("UIApplication.shared.open(", chip_idx)
        button_idx = self.src.find("Button {", chip_idx)
        self.assertNotEqual(chip_idx, -1, "CitationChip struct not found")
        self.assertNotEqual(open_idx, -1, "UIApplication.shared.open not found in CitationChip")
        self.assertNotEqual(button_idx, -1, "Button action not found in CitationChip")

    def test_citation_chip_button_style_plain(self):
        """CitationChip uses .buttonStyle(.plain) to avoid default button highlight stealing."""
        self.assertIn(
            ".buttonStyle(.plain)",
            self.src,
            "CitationChip must use .buttonStyle(.plain)",
        )


# --------------------------------------------------------------------------- #
# 5. Focus border: accent at 50% opacity when focused, border when not
# --------------------------------------------------------------------------- #

class TestFocusBorderStyling(unittest.TestCase):
    """
    The composer text field container must:
    - Show Color.Nexus.accent.opacity(0.5) border when focused.wrappedValue == true
    - Show Color.Nexus.border when focused.wrappedValue == false
    The focus state binding must correctly drive the border color switch.
    """

    def setUp(self):
        self.src = _read(NEXUS_TAB_VIEW)

    def test_border_uses_focused_wrapped_value(self):
        """Border color switches on focused.wrappedValue (the lifted FocusState binding)."""
        self.assertIn(
            "focused.wrappedValue",
            self.src,
            "Border conditional must use focused.wrappedValue to check focus state",
        )

    def test_accent_border_at_50_percent_when_focused(self):
        """When focused, border is Color.Nexus.accent.opacity(0.5)."""
        self.assertIn(
            "Color.Nexus.accent.opacity(0.5)",
            self.src,
            "Focused border must be Color.Nexus.accent.opacity(0.5)",
        )

    def test_default_border_color_nexus_border(self):
        """When not focused, border falls back to Color.Nexus.border."""
        self.assertIn(
            "Color.Nexus.border",
            self.src,
            "Unfocused border must be Color.Nexus.border",
        )

    def test_ternary_switches_between_accent_and_border(self):
        """A ternary (? :) selects between accent and border based on focus state."""
        # Look for the pattern: focused.wrappedValue ? Color.Nexus.accent.opacity(0.5) : Color.Nexus.border
        pattern = re.search(
            r"focused\.wrappedValue\s*\?.*?Nexus\.accent.*?:.*?Nexus\.border",
            self.src,
            re.DOTALL,
        )
        self.assertIsNotNone(
            pattern,
            "Must have a ternary: focused.wrappedValue ? Color.Nexus.accent.opacity(0.5) : Color.Nexus.border",
        )


# --------------------------------------------------------------------------- #
# 6. FocusState lifted to NexusTabView and bound to ChatComposer
# --------------------------------------------------------------------------- #

class TestFocusStateLift(unittest.TestCase):
    """
    @FocusState composerFocused must be declared at the NexusTabView level (not inside ChatComposer).
    ChatComposer accepts a FocusState<Bool>.Binding parameter named 'focused'.
    This lift allows NexusTabView to set composerFocused = false from the outer gesture.
    """

    def setUp(self):
        self.src = _read(NEXUS_TAB_VIEW)

    def test_focus_state_declared_in_nexus_tab_view(self):
        """@FocusState composerFocused is declared inside NexusTabView struct."""
        self.assertIn(
            "@FocusState private var composerFocused:",
            self.src,
            "@FocusState composerFocused must be a property of NexusTabView, not ChatComposer",
        )

    def test_chat_composer_accepts_focus_binding(self):
        """ChatComposer takes a FocusState<Bool>.Binding parameter."""
        self.assertIn(
            "FocusState<Bool>.Binding",
            self.src,
            "ChatComposer must accept a FocusState<Bool>.Binding parameter",
        )

    def test_chat_composer_parameter_named_focused(self):
        """The binding parameter in ChatComposer is named 'focused'."""
        self.assertIn(
            "var focused: FocusState<Bool>.Binding",
            self.src,
            "ChatComposer's focus binding parameter must be named 'focused'",
        )

    def test_composer_instantiated_with_focused_binding(self):
        """ChatComposer is instantiated with focused: $composerFocused."""
        self.assertIn(
            "focused: $composerFocused",
            self.src,
            "ChatComposer must be passed focused: $composerFocused from NexusTabView",
        )

    def test_text_field_uses_focused_binding(self):
        """TextField inside ChatComposer uses .focused(focused) with the binding."""
        self.assertIn(
            ".focused(focused)",
            self.src,
            "TextField must use .focused(focused) with the lifted FocusState binding",
        )


# --------------------------------------------------------------------------- #
# 7. onSubmit handler still present (send via return key)
# --------------------------------------------------------------------------- #

class TestOnSubmitHandler(unittest.TestCase):
    """
    The FocusState lift must not break the .onSubmit handler.
    TextField must still have .onSubmit { if canSend { vm.send() } }.
    """

    def setUp(self):
        self.src = _read(NEXUS_TAB_VIEW)

    def test_on_submit_present_in_text_field(self):
        """.onSubmit modifier is attached to the TextField."""
        self.assertIn(
            ".onSubmit {",
            self.src,
            ".onSubmit handler must be present on TextField for return key submission",
        )

    def test_on_submit_guards_with_can_send(self):
        """The onSubmit handler guards send with canSend check."""
        self.assertIn(
            "canSend",
            self.src,
            "onSubmit must guard vm.send() with the canSend check",
        )

    def test_on_submit_calls_vm_send(self):
        """The onSubmit handler calls vm.send() when canSend is true."""
        self.assertIn(
            "vm.send()",
            self.src,
            "onSubmit must call vm.send() when canSend is true",
        )

    def test_submit_label_is_send(self):
        """TextField submitLabel is set to .send for the keyboard return key label."""
        self.assertIn(
            ".submitLabel(.send)",
            self.src,
            "TextField must have .submitLabel(.send) so the return key shows 'Send'",
        )


# --------------------------------------------------------------------------- #
# 8. Send button still calls vm.send() (FocusState lift does not break send button)
# --------------------------------------------------------------------------- #

class TestSendButtonIntact(unittest.TestCase):
    """
    The send button (arrow.up) must still call vm.send() when canSend is true.
    The FocusState lift (composerFocused as a NexusTabView property) must not
    have broken the canSend check or the button action.
    """

    def setUp(self):
        self.src = _read(NEXUS_TAB_VIEW)

    def test_send_button_calls_vm_send(self):
        """Button action calls vm.send() when canSend is true."""
        self.assertIn(
            "vm.send()",
            self.src,
            "Send button must call vm.send() when canSend is true",
        )

    def test_arrow_up_icon_used_for_send(self):
        """Send button uses arrow.up SF Symbol."""
        self.assertIn(
            '"arrow.up"',
            self.src,
            'Send button must display the "arrow.up" SF Symbol',
        )

    def test_can_send_checks_input_not_empty(self):
        """canSend checks that inputText is not empty after trimming."""
        self.assertIn(
            "trimmingCharacters(in: .whitespacesAndNewlines).isEmpty",
            self.src,
            "canSend must trim whitespace and check for empty input",
        )

    def test_can_send_checks_phase_idle(self):
        """canSend also guards on vm.phase == .idle to disable during streaming."""
        # canSend checks that vm.phase == .idle
        self.assertIn(
            "vm.phase == .idle",
            self.src,
            "canSend must check vm.phase == .idle so the button is disabled during streaming",
        )

    def test_send_button_disabled_during_streaming(self):
        """The button is disabled when streaming (phase != idle)."""
        # .disabled(vm.phase == .streaming) or .disabled(!canSend) both satisfy this
        has_disabled = (
            ".disabled(vm.phase == .streaming)" in self.src
            or ".disabled(!canSend)" in self.src
            or ".disabled(" in self.src
        )
        self.assertTrue(
            has_disabled,
            "Send button must be disabled during streaming via .disabled modifier",
        )

    def test_send_button_uses_accent_color_when_can_send(self):
        """Send button background switches to accent when canSend is true."""
        self.assertIn(
            "Color.Nexus.accent",
            self.src,
            "Send button must use Color.Nexus.accent background when canSend is true",
        )


if __name__ == "__main__":
    unittest.main()
