import SwiftUI

// MARK: - LoadingStateView
//
// Shared loading state. Renders the brand Echo-pulse animation (the same wait
// state as the Ask tab and the create-collection screen) — NOT shimmer skeleton
// cards. Srihari's standing preference: the logo animation over shimmers, which
// read as "content failed to load" (device feedback 2026-07-13, 2026-08-19).
//
// Usage:
//   LoadingStateView()               // centered Echo pulse
//   LoadingStateView(cardCount: 5)   // cardCount retained for call-site compat; ignored

struct LoadingStateView: View {
    var cardCount: Int = 3   // retained for source compatibility; no longer used

    var body: some View {
        EchoPulseView()
            .scaleEffect(1.8)
            .frame(width: 64, height: 64)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }
}
