import SwiftUI

/// Debug-only screen for iterating on glass effects.
/// Three styles selectable via segmented control — tap avatar to open menu panel.
struct GlassPlaygroundView: View {

    enum GlassStyle: String, CaseIterable {
        case uikit = "UIKit Blur"
        case ios26 = "iOS 26"
        case dark = "Dark Material"
    }

    @State private var menuOpen = false
    @State private var selectedStyle: GlassStyle = .uikit

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
            // ── Backdrop ─────────────────────────────────────────────
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
                .padding(.bottom, 100)
            }
            .background(NexusBackground().ignoresSafeArea())
            .ignoresSafeArea(edges: .top)

            // ── Scrim ─────────────────────────────────────────────────
            if menuOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { menuOpen = false }
            }

            // ── Avatar button ─────────────────────────────────────────
            PlaygroundAvatarButton(active: menuOpen) { menuOpen.toggle() }
                .padding(.trailing, NexusSpacing.standard)
                .padding(.top, NexusSpacing.safeTop + 6)

            // ── Glass menu card ───────────────────────────────────────
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    PlaygroundMenuCard(style: selectedStyle) { menuOpen = false }
                        .scaleEffect(menuOpen ? 1.0 : 0.72, anchor: .topTrailing)
                        .offset(y: menuOpen ? 0 : -4)
                        .opacity(menuOpen ? 1 : 0)
                        .animation(.spring(response: 0.38, dampingFraction: 0.52), value: menuOpen)
                        .allowsHitTesting(menuOpen)
                        .padding(.trailing, NexusSpacing.standard)
                }
                Spacer()
            }
            .padding(.top, NexusSpacing.safeTop + 6)
        }
        .safeAreaInset(edge: .bottom) {
            stylePicker
        }
        .navigationTitle("Glass Playground")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stylePicker: some View {
        VStack(spacing: 8) {
            Text("Glass style")
                .font(.Nexus.caption)
                .foregroundColor(.Nexus.ghost)

            Picker("Style", selection: $selectedStyle) {
                ForEach(GlassStyle.allCases, id: \.self) { style in
                    Text(style.rawValue).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, NexusSpacing.standard)
        .padding(.vertical, NexusSpacing.md)
        .background(.regularMaterial)
    }
}

// MARK: - Avatar button

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
                    .overlay(Circle().stroke(Color(UIColor.separator), lineWidth: NexusBorder.base))
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

// MARK: - Menu card (three glass approaches)

private struct PlaygroundMenuCard: View {
    let style: GlassPlaygroundView.GlassStyle
    let onClose: () -> Void

    private let rows: [(String, String)] = [
        ("person.circle", "Account"),
        ("gearshape", "Settings"),
        ("message", "Feedback"),
    ]

    var body: some View {
        switch style {
        case .ios26:
            if #available(iOS 26, *) {
                menuContent
                    .frame(width: 196)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 20, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            } else {
                uikitCard
            }
        case .dark:
            menuContent
                .frame(width: 196)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        case .uikit:
            uikitCard
        }
    }

    private var uikitCard: some View {
        menuContent
            .frame(width: 196)
            .background(
                ZStack {
                    VisualEffectBlur(style: .systemUltraThinMaterial, cornerRadius: 14)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.42))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    private var menuContent: some View {
        VStack(spacing: 0) {
            ForEach(rows, id: \.1) { icon, label in
                Button(action: onClose) {
                    HStack(spacing: 9) {
                        Image(systemName: icon)
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundColor(Color(UIColor.label))
                            .frame(width: 18, alignment: .center)
                        Text(label)
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundColor(Color(UIColor.label))
                        Spacer()
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider()

            Button(action: onClose) {
                HStack(spacing: 9) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundColor(Color(UIColor.label))
                        .frame(width: 18, alignment: .center)
                    Text("Sign out")
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundColor(Color(UIColor.label))
                    Spacer()
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
