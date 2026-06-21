import SwiftUI
import UIKit

// MARK: - HighlightableTextView
//
// UIViewRepresentable wrapping UITextView to support tap-to-highlight in the reader.
// Isolated in its own file per ARCH_BRIEF §1D-004 ("UITextView isolated in its own file").
//
// Why UIViewRepresentable and not native SwiftUI Text?
//   SwiftUI Text has no API to render character-range background highlights or to
//   intercept text selection with a custom toolbar. UITextView natively supports both
//   via NSAttributedString + UIMenuController / UIEditMenuInteraction.
//
// Highlight approach:
//   • Existing annotations are applied as NSAttributedString background-color attributes
//     before the UITextView renders. Re-applying happens whenever `annotations` changes.
//   • Text selection triggers the system UIMenuController/UIEditMenuInteraction with a
//     custom "Highlight" item. The Coordinator captures the selected NSRange, extracts
//     the text, and calls back to SwiftUI via `onSelectText`.
//   • Tapping an already-highlighted range opens a second menu item "Remove" —
//     detected by checking whether the tap point falls within an existing highlight range.
//
// Design tokens:
//   • plum  → Color.Nexus.accent (#7054AB) at 30% opacity
//   • amber → #F59E0B at 30% opacity
//   • sage  → #10B981 at 30% opacity

struct HighlightableTextView: UIViewRepresentable {

    let text: String
    let annotations: [Annotation]
    let font: UIFont
    let textColor: UIColor
    let onSelectText: (SelectedTextInfo) -> Void
    let onTapHighlight: (Annotation) -> Void

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.isScrollEnabled = false          // parent SwiftUI ScrollView handles scrolling
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.dataDetectorTypes = []           // disable URL/phone auto-detection
        tv.delegate = context.coordinator

        // Long-press gesture to capture selection coordinates
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tv.addGestureRecognizer(tap)

        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        context.coordinator.parent = self
        applyAttributedText(to: tv)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Attributed text builder

    private func applyAttributedText(to tv: UITextView) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle,
            .kern: 0.2
        ]

        let attributed = NSMutableAttributedString(string: text, attributes: attrs)

        // Apply highlight backgrounds from annotations
        for annotation in annotations {
            let length = annotation.endOffset - annotation.startOffset
            guard annotation.startOffset >= 0,
                  length > 0,
                  annotation.startOffset + length <= text.utf16.count else { continue }

            let range = NSRange(location: annotation.startOffset, length: length)
            attributed.addAttribute(
                .backgroundColor,
                value: annotation.color.uiColor,
                range: range
            )
        }

        tv.attributedText = attributed
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: HighlightableTextView

        init(parent: HighlightableTextView) {
            self.parent = parent
        }

        // MARK: UITextViewDelegate

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Fired after user lifts finger from a text selection.
            // Show the highlight toolbar when a non-empty range is selected.
            let range = textView.selectedRange
            guard range.length > 0 else { return }

            guard let selectedText = (textView.text as NSString?)?.substring(with: range),
                  !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }

            let info = SelectedTextInfo(
                text: selectedText,
                startOffset: range.location,
                endOffset: range.location + range.length
            )
            // Dispatch async so the selection highlight renders before the toolbar appears
            DispatchQueue.main.async { [weak self] in
                self?.parent.onSelectText(info)
            }
        }

        // MARK: Tap handler — detect tap on existing highlight

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }
            let point = gesture.location(in: textView)

            // Find character index under tap
            guard let position = textView.closestPosition(to: point),
                  let range = textView.tokenizer.rangeEnclosingPosition(
                    position,
                    with: .character,
                    inDirection: .layout(.left)
                  ) else { return }

            let charIndex = textView.offset(from: textView.beginningOfDocument, to: range.start)

            // Check if this character falls within an existing annotation
            if let tapped = parent.annotations.first(where: {
                charIndex >= $0.startOffset && charIndex < $0.endOffset
            }) {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.onTapHighlight(tapped)
                }
            }
        }

        // MARK: UIGestureRecognizerDelegate — let system gestures pass through

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            return true
        }
    }
}

// MARK: - SelectedTextInfo

struct SelectedTextInfo {
    let text: String
    let startOffset: Int
    let endOffset: Int
}

// MARK: - HighlightColor → UIColor

extension HighlightColor {
    var uiColor: UIColor {
        switch self {
        case .plum:  return UIColor(red: 0x70/255.0, green: 0x54/255.0, blue: 0xAB/255.0, alpha: 0.30)
        case .amber: return UIColor(red: 0xF5/255.0, green: 0x9E/255.0, blue: 0x0B/255.0, alpha: 0.30)
        case .sage:  return UIColor(red: 0x10/255.0, green: 0xB9/255.0, blue: 0x81/255.0, alpha: 0.30)
        }
    }
}

// MARK: - HighlightColor → SwiftUI Color (for toolbar swatches)

extension HighlightColor {
    var swiftUIColor: Color {
        switch self {
        case .plum:  return Color.Nexus.accent.opacity(0.30)
        case .amber: return Color(hex: "#F59E0B").opacity(0.30)
        case .sage:  return Color(hex: "#10B981").opacity(0.30)
        }
    }

    // Solid version for the swatch border / label
    var swiftUISolidColor: Color {
        switch self {
        case .plum:  return Color.Nexus.accent
        case .amber: return Color(hex: "#F59E0B")
        case .sage:  return Color(hex: "#10B981")
        }
    }
}
