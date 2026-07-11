import SwiftUI

// MARK: - Bottom floating glass tab bar
//
// iOS 26+: NATIVE Liquid Glass (same system material as WhatsApp's tab bar).
//   • Track:  .glassEffect(.regular, in: .capsule) — no background fills, no
//     hand-drawn rims. An explicit .background() DEFEATS the glass material
//     entirely (that was v1's flat look).
//   • Thumb:  its own tinted interactive glass capsule inside the shared
//     GlassEffectContainer with a stable glassEffectID — moving it between
//     tabs morphs the glass liquidly (the WhatsApp water-bubble travel),
//     driven by matchedGeometryEffect + withAnimation.
// < iOS 26: ultraThinMaterial approximation (previous behavior).

struct GlassTabItem: Equatable {
    let key: String
    let label: String
    let icon: String          // SF Symbol; "echo" renders the brand mark
    let iconSelected: String
}

struct GlassTabBar: View {
    let tabs: [GlassTabItem]
    @Binding var selection: String

    @Namespace private var thumbNS
    @Namespace private var glassNS
    @State private var squash: CGSize = CGSize(width: 1, height: 1)

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                track
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
        } else {
            track
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.4), lineWidth: NexusBorder.hair)
                )
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 6)
        }
    }

    private var track: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.key) { tab in
                tabButton(tab)
            }
        }
        .padding(3)
    }

    private func tabButton(_ tab: GlassTabItem) -> some View {
        let isSelected = selection == tab.key
        return Button {
            guard selection != tab.key else { return }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.72)) {
                selection = tab.key
            }
            // Water-bubble squash layered on top of the native glass morph
            squash = CGSize(width: 1.13, height: 0.87)
            withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) {
                squash = CGSize(width: 1, height: 1)
            }
        } label: {
            VStack(spacing: 2) {
                tabIcon(tab, selected: isSelected)
                    .frame(height: 23)
                Text(tab.label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .kerning(-0.1)
                    .foregroundColor(isSelected ? .Nexus.accent : .Nexus.muted)
            }
            .padding(.top, 6)
            .padding(.bottom, 5)
            .padding(.horizontal, 22)
            .background { if isSelected { thumb } }
        }
        .buttonStyle(.plain)
    }

    // The traveling selection pill. On iOS 26 it is its own glass element —
    // glassEffectID inside the shared container gives the liquid morph as it
    // moves between tab positions.
    @ViewBuilder
    private var thumb: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.tint(Color.Nexus.accent.opacity(0.16)).interactive(), in: .capsule)
                .glassEffectID("selection-thumb", in: glassNS)
                .scaleEffect(x: squash.width, y: squash.height)
                .matchedGeometryEffect(id: "thumb", in: thumbNS)
        } else {
            Capsule()
                .fill(Color.white.opacity(0.66))
                .overlay(Capsule().stroke(Color.white.opacity(0.85), lineWidth: NexusBorder.hair))
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
                .scaleEffect(x: squash.width, y: squash.height)
                .matchedGeometryEffect(id: "thumb", in: thumbNS)
        }
    }

    @ViewBuilder
    private func tabIcon(_ tab: GlassTabItem, selected: Bool) -> some View {
        let tint: Color = selected ? .Nexus.accent : .Nexus.muted
        if tab.icon == "echo" {
            EchoMark(color: tint, size: 21)
        } else {
            Image(systemName: selected ? tab.iconSelected : tab.icon)
                .font(.system(size: 17.5, weight: .medium))
                .foregroundColor(tint)
        }
    }
}
