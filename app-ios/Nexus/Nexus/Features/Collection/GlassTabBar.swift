import SwiftUI

// MARK: - Bottom floating glass tab bar
//
// Ported from prototype /flows/qa TabCapsule (locked 2026-07-10):
//  • WhatsApp-height capsule: 23pt icon + 10.5pt label, tight padding.
//  • Liquid Glass material with chromatic hairline (DESIGN_LANGUAGE §3).
//  • Traveling thumb: glides between tabs on a spring AND squashes like a
//    water bubble mid-flight (scale 1.13×0.87 → 0.95×1.05 → settle).
//  • Selected tab: plum tint + filled icon variant where available.

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
    @State private var squash: CGSize = CGSize(width: 1, height: 1)

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.key) { tab in
                tabButton(tab)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.white.opacity(0.1),
                            Color(red: 150/255, green: 170/255, blue: 1).opacity(0.15),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: NexusBorder.hair
                )
        )
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 6)
        .shadow(color: Color.Nexus.accent.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func tabButton(_ tab: GlassTabItem) -> some View {
        let isSelected = selection == tab.key
        return Button {
            guard selection != tab.key else { return }
            // Glide + water-bubble squash, together (prototype: .52s spring
            // travel, .56s squash 1.13/0.87 → 0.95/1.05 → 1).
            withAnimation(.spring(response: 0.52, dampingFraction: 0.72)) {
                selection = tab.key
            }
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
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.white.opacity(0.66))
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.85), lineWidth: NexusBorder.hair)
                        )
                        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
                        .scaleEffect(x: squash.width, y: squash.height)
                        .matchedGeometryEffect(id: "thumb", in: thumbNS)
                }
            }
        }
        .buttonStyle(.plain)
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
