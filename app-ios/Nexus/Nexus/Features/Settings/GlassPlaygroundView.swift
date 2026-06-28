import SwiftUI

/// Debug-only screen for iterating on the Liquid Glass avatar menu.
/// Access: Settings → Glass Playground (DEBUG builds only).
///
/// Shows the menu card over a realistic collection-list backdrop so the
/// frosted-glass effect reads clearly against varied content.
struct GlassPlaygroundView: View {
    @State private var menuOpen = false

    private let mockCollections: [(String, String, Int)] = [
        ("The attention economy", "12 items · 2h ago", 0),
        ("Second-brain tools", "7 items · yesterday", 1),
        ("How memory works", "5 items · last week", 2),
        ("AI platform shifts", "3 items · 3 days ago", 3),
        ("Ozempic & longevity", "8 items · 5 days ago", 4),
        ("Vision Pro 2", "2 items · 1 week ago", 5),
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // ── Backdrop: realistic collection list ──────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Collections")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.Nexus.ink)
                        .padding(.horizontal, NexusSpacing.standard)
                        .padding(.top, NexusSpacing.safeTop + 16)

                    ForEach(mockCollections, id: \.2) { title, subtitle, _ in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.Nexus.ink)
                            Text(subtitle)
                                .font(.system(size: 13))
                                .foregroundColor(.Nexus.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color.Nexus.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: NexusRadius.base, style: .continuous)
                                .stroke(Color.Nexus.border, lineWidth: NexusBorder.base)
                        )
                        .padding(.horizontal, NexusSpacing.standard)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(NexusBackground().ignoresSafeArea())
            .ignoresSafeArea(edges: .top)

            // ── Scrim (same as production) ───────────────────────────
            if menuOpen {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { menuOpen = false }
            }

            // ── Avatar button ────────────────────────────────────────
            PlaygroundAvatarButton(active: menuOpen) { menuOpen.toggle() }
                .padding(.trailing, NexusSpacing.standard)
                .padding(.top, NexusSpacing.safeTop + 6)

            // ── Glass menu card ──────────────────────────────────────
            VStack {
                HStack {
                    Spacer()
                    PlaygroundMenuCard { menuOpen = false }
                        .padding(.trailing, NexusSpacing.standard)
                }
                Spacer()
            }
            .padding(.top, NexusSpacing.safeTop + 6 + 32 + 6)
            .scaleEffect(menuOpen ? 1.0 : 0.82, anchor: .topTrailing)
            .offset(y: menuOpen ? 0 : -6)
            .opacity(menuOpen ? 1 : 0)
            .animation(.spring(response: 0.26, dampingFraction: 0.62), value: menuOpen)
            .allowsHitTesting(menuOpen)
        }
        .navigationTitle("Glass Playground")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Components (mirror of production; edit here, then copy across)

private struct PlaygroundAvatarButton: View {
    let active: Bool
    let action: () -> Void
    @State private var pressing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(active ? Color.Nexus.bloom : Color.Nexus.surface2)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle().stroke(Color(UIColor.separator), lineWidth: NexusBorder.base)
                    )
                Text("S")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(active ? Color.Nexus.accent : .Nexus.muted)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(pressing ? 0.88 : 1.0)
        .animation(.spring(response: 0.18, dampingFraction: 0.65), value: pressing)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressing = true }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { pressing = false }
                }
        )
    }
}

private struct PlaygroundMenuCard: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.Nexus.bloom).frame(width: 36, height: 36)
                    Text("S")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.Nexus.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Srihari")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(UIColor.label))
                    Text("srihari.scorp@gmail.com")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 10)

            Divider().padding(.horizontal, 8)

            ForEach(["Account", "Settings", "Feedback"], id: \.self) { label in
                Button(action: onClose) {
                    Text(label)
                        .font(.system(size: 14.5))
                        .foregroundColor(Color(UIColor.label))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.horizontal, 8)

            Button(action: onClose) {
                Text("Sign out")
                    .font(.system(size: 14.5))
                    .foregroundColor(Color(UIColor.label))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 9)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.11), radius: 28, x: 0, y: 8)
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        .environment(\.colorScheme, .light)
    }
}
