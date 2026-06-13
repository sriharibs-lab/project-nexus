// Generated from design-system/tokens/motion.json — do not edit manually.
import SwiftUI

enum NexusDuration {
    static let instant:   Double = 0.05
    static let fast:      Double = 0.15
    static let base:      Double = 0.24   // press bounce
    static let moderate:  Double = 0.38   // pane swipe, tab thumb
    static let slow:      Double = 0.48   // page push/pop
    static let sheet:     Double = 0.52   // bottom sheet rise
    static let menuOpen:  Double = 0.42
    static let menuClose: Double = 0.26
}

enum NexusAnimation {
    // Press bounce — every tappable element
    static let press = Animation.timingCurve(0.18, 1.5, 0.4, 1.0, duration: NexusDuration.base)

    // Page navigation
    static let pageForward = Animation.timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.slow)
    static let pageBack    = Animation.timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.moderate)

    // Sheet / modal
    static let sheetRise    = Animation.timingCurve(0.32, 0.72, 0.28, 1.0, duration: NexusDuration.sheet)
    static let sheetDismiss = Animation.timingCurve(0.4, 0.0, 0.9, 0.35, duration: NexusDuration.menuClose)

    // Pivot tab slide
    static let pivot = Animation.timingCurve(0.2, 0.8, 0.2, 1.0, duration: NexusDuration.moderate)

    // Element fade (menu close, tooltip)
    static let element = Animation.timingCurve(0.4, 0.0, 0.9, 0.35, duration: NexusDuration.menuClose)
}

// Press scale values — apply with .scaleEffect()
enum NexusScale {
    static let pressLight:  CGFloat = 0.97   // rows, chips
    static let pressBase:   CGFloat = 0.93   // standard Pressable
    static let pressHeavy:  CGFloat = 0.88   // icon buttons
    static let pressAvatar: CGFloat = 0.84   // avatar / back button
}
