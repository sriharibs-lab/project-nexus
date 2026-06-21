import SwiftUI

// MARK: - ErrorStateView
//
// Reusable error state component: icon, message, and retry callback.
//
// Pattern: matches the existing ErrorBanner in NexusTabView (inline, no glass)
// but is a full-screen centred layout for full-page error surfaces.
//
// Usage:
//   ErrorStateView(message: "Couldn't load sources.") {
//       await vm.load()
//   }
//
// The retry action is an async closure so callers can directly
// forward their ViewModel load() methods.
//
// Design rules (DESIGN_LANGUAGE.md):
//   • Error icon muted (ghost color) — not alarming
//   • One ink-filled CTA per surface: "Try again" in accent
//   • No red backgrounds — error is communicated via copy, not color

struct ErrorStateView: View {
    let message: String
    let onRetry: () async -> Void

    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: NexusSpacing.xl) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.Nexus.surface2)
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(Color.Nexus.surface2)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
                    )

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.Nexus.ghost)
            }

            // Message
            VStack(spacing: NexusSpacing.sm) {
                Text("Something went wrong")
                    .font(.Nexus.headingSmall)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.tighter)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NexusSpacing.xxxl)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Retry button
            Button {
                Task {
                    isRetrying = true
                    await onRetry()
                    isRetrying = false
                }
            } label: {
                HStack(spacing: NexusSpacing.sm) {
                    if isRetrying {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Text(isRetrying ? "Retrying…" : "Try again")
                        .font(.Nexus.labelLarge)
                        .kerning(NexusKerning.normal)
                }
                .foregroundColor(.white)
                .padding(.horizontal, NexusSpacing.xl)
                .frame(height: NexusSpacing.buttonHeight)
                .background(isRetrying ? Color.Nexus.ghost : Color.Nexus.accent)
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
                .animation(NexusAnimation.element, value: isRetrying)
            }
            .buttonStyle(.plain)
            .disabled(isRetrying)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, NexusSpacing.sideGutter)
    }
}
