import SwiftUI

// MARK: - Avatar menu (native)
//
// NATIVE `Menu` (2026-07-16 device review): the Weather-app ellipsis pattern.
// Custom bloom overlays can never show Liquid Glass — animated opacity/scale
// modifiers flatten glassEffect into an opaque snapshot (same lesson as the
// tab bar: wrap the native control, don't reimplement it). Native gives:
//  • true glass material + spring pop, system-tuned
//  • the menu floats OVER the avatar; the button never disappears
//  • dismiss/anchor/accessibility handled by iOS
// Rows (locked IA 2026-07-16): Account · Settings · Feedback.

struct NexusAvatarMenu: View {
    let onAccount: () -> Void
    let onSettings: () -> Void
    let onFeedback: () -> Void

    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        Menu {
            Button(action: onAccount) {
                Label("Account", systemImage: "person.circle")
            }
            Button(action: onSettings) {
                Label("Settings", systemImage: "gearshape")
            }
            Button(action: onFeedback) {
                Label("Feedback", systemImage: "message")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.Nexus.surface2)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.Nexus.borderStrong, lineWidth: 1.0))
                Text(authManager.avatarInitial)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.Nexus.muted)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
