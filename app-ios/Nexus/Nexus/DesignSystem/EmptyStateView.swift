import SwiftUI

// MARK: - EmptyStateView
//
// Reusable empty state component used across all Nexus screens.
//
// Usage:
//   EmptyStateView(
//       icon: "doc.text.magnifyingglass",
//       title: "No sources yet",
//       subtitle: "Add a source to start building this collection.",
//       action: EmptyStateView.Action(label: "Add a source") { addSource() }
//   )
//
// Design rules (DESIGN_LANGUAGE.md):
//   • Soft plum accent on icon tray — on-brand without being loud
//   • Single plum-filled CTA (if provided) — accent used once per surface
//   • Centered layout, adequate breathing room above/below
//   • Body copy uses SPEC §5a terminology (e.g. "source", "collection")

struct EmptyStateView: View {
    struct Action {
        let label: String
        let handler: () -> Void
    }

    let icon: String
    let title: String
    let subtitle: String
    var action: Action? = nil

    var body: some View {
        VStack(spacing: NexusSpacing.xl) {
            // Icon tray — plum-bloom wash, accent icon
            iconTray

            // Text block
            VStack(spacing: NexusSpacing.sm) {
                Text(title)
                    .font(.Nexus.headingSmall)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.tighter)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NexusSpacing.xxxl)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Optional CTA
            if let action {
                ctaButton(action)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, NexusSpacing.sideGutter)
    }

    // MARK: - Icon tray

    private var iconTray: some View {
        ZStack {
            // Outer bloom ring
            Circle()
                .fill(Color.Nexus.bloom.opacity(0.4))
                .frame(width: 72, height: 72)

            // Inner surface
            Circle()
                .fill(Color.Nexus.bloom.opacity(0.7))
                .frame(width: 52, height: 52)
                .overlay(
                    Circle()
                        .stroke(Color.Nexus.accent.opacity(0.15), lineWidth: NexusBorder.hair)
                )

            // Icon
            Image(systemName: icon)
                .font(.system(size: 22, weight: .light))
                .foregroundColor(Color.Nexus.accent)
        }
    }

    // MARK: - CTA button

    private func ctaButton(_ action: Action) -> some View {
        Button(action: action.handler) {
            Text(action.label)
                .font(.Nexus.labelLarge)
                .kerning(NexusKerning.normal)
                .foregroundColor(.white)
                .padding(.horizontal, NexusSpacing.xl)
                .frame(height: NexusSpacing.buttonHeight)
                .background(Color.Nexus.accent)
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
        }
        .buttonStyle(.plain)
    }
}
