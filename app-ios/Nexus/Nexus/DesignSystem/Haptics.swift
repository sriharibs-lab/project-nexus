import UIKit

/// Tasteful, centralized haptics. Used sparingly — only for moments that
/// genuinely benefit from physical feedback (answering a quiz, kicking off a
/// generation), never for routine taps the system already handles.
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
