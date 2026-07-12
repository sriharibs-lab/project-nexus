import SwiftUI

// MARK: - Bottom floating glass tab bar
//
// iOS 26+: NATIVE Liquid Glass (chosen in Glass Playground review 2026-07-11).
//
// The water-droplet travel (WhatsApp/FotMob) requires the selection thumb to
// be a SIBLING glass element inside the same GlassEffectContainer as the
// track — NOT nested inside the track's glass. A nested pill is invisible to
// the container's morph pass; a sibling glass capsule whose position animates
// gets fluid deformation in flight for free. Button frames are measured via
// a PreferenceKey in the track's coordinate space and the thumb is overlaid
// at the selected button's frame.
//
// < iOS 26: ultraThinMaterial + matchedGeometry thumb (previous behavior).

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
    @State private var tabFrames: [String: CGRect] = [:]

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                ZStack(alignment: .topLeading) {
                    track
                        .glassEffect(.regular.interactive(), in: .capsule)

                    // Sibling glass droplet — animating offset = liquid travel
                    if let frame = tabFrames[selection] {
                        Capsule()
                            .fill(.clear)
                            .glassEffect(
                                .regular.tint(Color.Nexus.accent.opacity(0.16)).interactive(),
                                in: .capsule
                            )
                            .glassEffectID("selection-droplet", in: glassNS)
                            .frame(width: frame.width, height: frame.height)
                            .offset(x: frame.minX, y: frame.minY)
                            .allowsHitTesting(false)
                    }
                }
            }
            .coordinateSpace(name: "glasstrack")
            .onPreferenceChange(TabFramePreference.self) { tabFrames = $0 }
        } else {
            legacyBar
        }
    }

    // MARK: - Track (buttons only — the droplet is overlaid by the parent)

    private var track: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.key) { tab in
                tabButton(tab, reportFrame: true, legacyThumb: false)
            }
        }
        .padding(3)
    }

    // MARK: - Legacy bar (< iOS 26)

    private var legacyBar: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.key) { tab in
                tabButton(tab, reportFrame: false, legacyThumb: true)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.4), lineWidth: NexusBorder.hair)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 6)
    }

    // MARK: - Button

    private func tabButton(_ tab: GlassTabItem, reportFrame: Bool, legacyThumb: Bool) -> some View {
        let isSelected = selection == tab.key
        return Button {
            guard selection != tab.key else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                selection = tab.key
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
                if reportFrame {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: TabFramePreference.self,
                            value: [tab.key: geo.frame(in: .named("glasstrack"))]
                        )
                    }
                }
                if legacyThumb, isSelected {
                    Capsule()
                        .fill(Color.white.opacity(0.66))
                        .overlay(Capsule().stroke(Color.white.opacity(0.85), lineWidth: NexusBorder.hair))
                        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
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

// MARK: - Frame preference

private struct TabFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
