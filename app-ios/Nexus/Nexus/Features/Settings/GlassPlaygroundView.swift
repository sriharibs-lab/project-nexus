import SwiftUI

// MARK: - Glass Playground
//
// Isolated lab for getting Liquid Glass RIGHT (2026-07-11 review: glass work
// moves here; the product tab bar ships whatever this proves out).
//
// Key physics: glass only "lights up" when content moves UNDERNEATH it.
// This playground scrolls vivid content behind each variant — compare
// directly against WhatsApp/FotMob by scrolling.

struct GlassPlaygroundView: View {
    @State private var variant: GlassVariant = .native
    @State private var selection = "ask"

    enum GlassVariant: String, CaseIterable, Identifiable {
        case native   = "Native"
        case clear    = "Clear"
        case tinted   = "Tinted"
        case material = "Material"
        var id: String { rawValue }

        var caption: String {
            switch self {
            case .native:   return ".glassEffect(.regular) — system default, same as WhatsApp"
            case .clear:    return ".glassEffect(.clear) — maximum transparency"
            case .tinted:   return ".regular.tint(bloom) — brand-tinted glass"
            case .material: return "ultraThinMaterial — the pre-iOS-26 fallback"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Vivid scrolling content — the glass needs this to refract ──
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(0..<24, id: \.self) { i in
                        DemoCard(index: i)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 150)
            }

            // ── The bar under test ──
            VStack(spacing: 10) {
                Text(variant.caption)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.Nexus.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.Nexus.cardBackground.opacity(0.9))
                    .clipShape(Capsule())

                demoBar

                Picker("Variant", selection: $variant) {
                    ForEach(GlassVariant.allCases) { v in
                        Text(v.rawValue).tag(v)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 16)
        }
        .navigationTitle("Glass Playground")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Bar variants

    private static let tabs: [GlassTabItem] = [
        GlassTabItem(key: "ask",     label: "Ask",     icon: "echo",              iconSelected: "echo"),
        GlassTabItem(key: "create",  label: "Create",  icon: "square.and.pencil", iconSelected: "square.and.pencil"),
        GlassTabItem(key: "sources", label: "Sources", icon: "rectangle.stack",   iconSelected: "rectangle.stack.fill"),
    ]

    @ViewBuilder
    private var demoBar: some View {
        switch variant {
        case .native:
            GlassTabBar(tabs: Self.tabs, selection: $selection)
        case .clear:
            if #available(iOS 26.0, *) {
                PlaygroundBar(tabs: Self.tabs, selection: $selection) { track in
                    AnyView(track.glassEffect(.clear.interactive(), in: .capsule))
                }
            } else {
                unavailableNote
            }
        case .tinted:
            if #available(iOS 26.0, *) {
                PlaygroundBar(tabs: Self.tabs, selection: $selection) { track in
                    AnyView(track.glassEffect(
                        .regular.tint(Color.Nexus.bloom.opacity(0.5)).interactive(),
                        in: .capsule
                    ))
                }
            } else {
                unavailableNote
            }
        case .material:
            PlaygroundBar(tabs: Self.tabs, selection: $selection) { track in
                AnyView(
                    track
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: NexusBorder.hair))
                        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 6)
                )
            }
        }
    }

    private var unavailableNote: some View {
        Text("Requires iOS 26")
            .font(.Nexus.caption)
            .foregroundColor(.Nexus.muted)
            .padding()
    }
}

// MARK: - Parameterized bar (playground only — product uses GlassTabBar)

private struct PlaygroundBar: View {
    let tabs: [GlassTabItem]
    @Binding var selection: String
    let chrome: (AnyView) -> AnyView

    @Namespace private var thumbNS

    var body: some View {
        chrome(AnyView(track))
    }

    private var track: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.key) { tab in
                let isSelected = selection == tab.key
                Button {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.72)) {
                        selection = tab.key
                    }
                } label: {
                    VStack(spacing: 2) {
                        Group {
                            if tab.icon == "echo" {
                                EchoMark(color: isSelected ? .Nexus.accent : .Nexus.muted, size: 21)
                            } else {
                                Image(systemName: isSelected ? tab.iconSelected : tab.icon)
                                    .font(.system(size: 17.5, weight: .medium))
                                    .foregroundColor(isSelected ? .Nexus.accent : .Nexus.muted)
                            }
                        }
                        .frame(height: 23)
                        Text(tab.label)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(isSelected ? .Nexus.accent : .Nexus.muted)
                    }
                    .padding(.top, 6).padding(.bottom, 5).padding(.horizontal, 22)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Color.white.opacity(0.55))
                                .matchedGeometryEffect(id: "pthumb", in: thumbNS)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
    }
}

// MARK: - Vivid demo content

private struct DemoCard: View {
    let index: Int

    private static let palettes: [[Color]] = [
        [Color(red: 0.98, green: 0.45, blue: 0.35), Color(red: 0.95, green: 0.65, blue: 0.30)],
        [Color(red: 0.30, green: 0.55, blue: 0.95), Color(red: 0.45, green: 0.80, blue: 0.95)],
        [Color(red: 0.45, green: 0.75, blue: 0.45), Color(red: 0.75, green: 0.90, blue: 0.50)],
        [Color(red: 0.55, green: 0.40, blue: 0.90), Color(red: 0.85, green: 0.50, blue: 0.90)],
        [Color(red: 0.95, green: 0.75, blue: 0.25), Color(red: 0.98, green: 0.55, blue: 0.45)],
    ]

    var body: some View {
        let colors = Self.palettes[index % Self.palettes.count]
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(height: 110)
            .overlay(alignment: .bottomLeading) {
                Text("Scroll me under the bar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(12)
            }
    }
}
