import SwiftUI

// MARK: - Bottom floating glass tab bar
//
// iOS 26+: NATIVE Liquid Glass, FotMob interaction pattern (review 2026-07-11):
//   • ONE tap/drag gesture on the whole capsule — no Buttons. Buttons under
//     interactive glass swallowed taps (the "tap twice or thrice" bug), and
//     the track's .interactive() bounced the whole bar. Tap = select tab at
//     finger; press-and-slide = the droplet FOLLOWS the finger and snaps to
//     the nearest tab on release (native TabView behavior).
//   • The droplet is a SIBLING glass element in the GlassEffectContainer —
//     its animated position gets liquid deformation from the system.
//   • Icons: always the FILLED variant; color carries selection state
//     (muted → accent), exactly like FotMob.
//
// < iOS 26: material bar with buttons + matchedGeometry thumb (unchanged).

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

    // Finger-following droplet state
    @State private var dragX: CGFloat?
    @State private var isDragging = false

    var body: some View {
        if #available(iOS 26.0, *) {
            glassBar
        } else {
            legacyBar
        }
    }

    // MARK: - iOS 26 glass bar

    @available(iOS 26.0, *)
    private var glassBar: some View {
        GlassEffectContainer(spacing: 18) {
            ZStack(alignment: .topLeading) {
                track
                    .glassEffect(.regular, in: .capsule)

                if let frame = dropletFrame {
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
                        // While the finger drives it, no implicit animation —
                        // it must track 1:1; the release snap animates via
                        // withAnimation in the gesture's onEnded.
                        .animation(isDragging ? nil : .spring(response: 0.45, dampingFraction: 0.72), value: frame)
                }
            }
        }
        .coordinateSpace(name: "glasstrack")
        .onPreferenceChange(TabFramePreference.self) { tabFrames = $0 }
        .contentShape(Capsule())
        .gesture(barGesture)
    }

    /// Where the droplet sits right now: under the finger while dragging,
    /// otherwise on the selected tab.
    private var dropletFrame: CGRect? {
        guard let selected = tabFrames[selection] else { return nil }
        guard isDragging, let x = dragX else { return selected }
        let minX = tabFrames.values.map(\.minX).min() ?? selected.minX
        let maxX = tabFrames.values.map(\.maxX).max() ?? selected.maxX
        let clampedCenter = min(max(x, minX + selected.width / 2), maxX - selected.width / 2)
        return CGRect(
            x: clampedCenter - selected.width / 2,
            y: selected.minY,
            width: selected.width,
            height: selected.height
        )
    }

    /// The tab a given x-position lands on (nearest by center distance).
    private func tab(atX x: CGFloat) -> String {
        tabFrames.min { abs($0.value.midX - x) < abs($1.value.midX - x) }?.key ?? selection
    }

    /// Tab whose color should light up right now (live feedback mid-drag).
    private var highlightedKey: String {
        if isDragging, let x = dragX { return tab(atX: x) }
        return selection
    }

    private var barGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("glasstrack"))
            .onChanged { value in
                dragX = value.location.x
                // A tap stays a tap; the droplet detaches after slight movement
                if abs(value.translation.width) > 6 { isDragging = true }
            }
            .onEnded { value in
                let target = tab(atX: value.location.x)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    selection = target
                    isDragging = false
                }
                dragX = nil
            }
    }

    private var track: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.key) { tab in
                tabCell(tab, highlighted: highlightedKey == tab.key)
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TabFramePreference.self,
                                value: [tab.key: geo.frame(in: .named("glasstrack"))]
                            )
                        }
                    }
            }
        }
        .padding(3)
    }

    private func tabCell(_ tab: GlassTabItem, highlighted: Bool) -> some View {
        VStack(spacing: 2) {
            tabIcon(tab, highlighted: highlighted)
                .frame(height: 23)
            Text(tab.label)
                .font(.system(size: 10.5, weight: .semibold))
                .kerning(-0.1)
                .foregroundColor(highlighted ? .Nexus.accent : .Nexus.muted)
        }
        .padding(.top, 6)
        .padding(.bottom, 5)
        .padding(.horizontal, 22)
        .animation(.easeOut(duration: 0.15), value: highlighted)
    }

    // FotMob pattern: filled glyphs ALWAYS; only the color changes with state.
    @ViewBuilder
    private func tabIcon(_ tab: GlassTabItem, highlighted: Bool) -> some View {
        let tint: Color = highlighted ? .Nexus.accent : .Nexus.muted
        if tab.icon == "echo" {
            EchoMark(color: tint, size: 21)
        } else {
            Image(systemName: tab.iconSelected)
                .font(.system(size: 17.5, weight: .semibold))
                .foregroundColor(tint)
        }
    }

    // MARK: - Legacy bar (< iOS 26)

    private var legacyBar: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.key) { tab in
                legacyButton(tab)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.4), lineWidth: NexusBorder.hair)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 6)
    }

    private func legacyButton(_ tab: GlassTabItem) -> some View {
        let isSelected = selection == tab.key
        return Button {
            guard selection != tab.key else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                selection = tab.key
            }
        } label: {
            tabCell(tab, highlighted: isSelected)
                .background {
                    if isSelected {
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
}

// MARK: - Frame preference

private struct TabFramePreference: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
