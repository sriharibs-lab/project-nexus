import SwiftUI
import UIKit

// MARK: - Bottom floating glass tab bar
//
// BREAKTHROUGH (2026-07-11 device review): the exact liquid-glass selection
// effect Srihari wants — droplet slides between segments, deforms in flight,
// follows the finger on drag — is the NATIVE UISegmentedControl treatment on
// iOS 26 (spotted on the playground's variant Picker). We stop reimplementing
// the physics and wrap the real control, feeding it our tab cells (icon +
// label) as rendered images. The system owns the glass, the droplet, and the
// gesture handling — taps are 100% reliable.
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

    var body: some View {
        if #available(iOS 26.0, *) {
            // Glass backdrop BEHIND the native control (Clock-app pattern):
            // the control's own track is nearly transparent, so without this
            // the bar doesn't separate from content scrolling underneath.
            NativeSegmentedTabBar(tabs: tabs, selection: $selection)
                .fixedSize()
                .glassEffect(.regular, in: .capsule)
        } else {
            legacyBar
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
            TabCellView(tab: tab, highlighted: isSelected)
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

// MARK: - Tab cell (shared by both paths; rendered to UIImage for the native control)

private struct TabCellView: View {
    let tab: GlassTabItem
    let highlighted: Bool

    var body: some View {
        // Filled glyphs always; color carries selection state. Unselected is
        // soft near-black — jet black stood out too much (review 2026-07-14).
        let tint: Color = highlighted ? .Nexus.accent : Color.Nexus.ink.opacity(0.72)
        VStack(spacing: 3) {
            Group {
                switch tab.icon {
                case "echo":
                    EchoMark(color: tint, size: 24)
                case "sparkleBubble":
                    // Ask — chat bubble with a sparkle inside.
                    // Fixed frame: offset sparkles made ImageRenderer output
                    // size wobble between bakes, feeding the layout loop.
                    ZStack {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(tint)
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .offset(y: -1.5)
                    }
                    .frame(width: 30, height: 26)
                case "sparklePhoto":
                    // Create — image with a sparkle at its corner (Canva/Figma)
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(tint)
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(tint)
                            .offset(x: 6, y: -5)
                    }
                    .frame(width: 30, height: 26)
                default:
                    Image(systemName: tab.iconSelected)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(tint)
                }
            }
            .frame(height: 26)
            Text(tab.label)
                .font(.system(size: 11, weight: .semibold))
                .kerning(-0.1)
                .foregroundColor(tint)
        }
        .padding(.top, 5)
        .padding(.bottom, 4)
        // Wide horizontal padding → the selection pill reads as an OVAL,
        // not a circle (Clock-app proportions, review 2026-07-11)
        .padding(.horizontal, 28)
    }
}

// MARK: - Native segmented control wrapper (iOS 26)

@available(iOS 26.0, *)
private struct NativeSegmentedTabBar: UIViewRepresentable {
    let tabs: [GlassTabItem]
    @Binding var selection: String

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: [UIImage()])
        control.removeAllSegments()
        for (i, tab) in tabs.enumerated() {
            control.insertSegment(
                with: Self.cellImage(tab, highlighted: tab.key == selection),
                at: i,
                animated: false
            )
        }
        control.apportionsSegmentWidthsByContent = true
        control.selectedSegmentIndex = tabs.firstIndex { $0.key == selection } ?? 0
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.changed(_:)),
            for: .valueChanged
        )
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .vertical)
        return control
    }

    // WhatsApp/FotMob/Clock-app height. A heightAnchor constraint fights
    // SwiftUI's sizing of representables (it uses sizeThatFits and squished
    // the bar to the control's ~32pt intrinsic height) — report the size here.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        let intrinsic = uiView.intrinsicContentSize
        return CGSize(width: intrinsic.width, height: 58)
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        context.coordinator.parent = self
        let idx = tabs.firstIndex { $0.key == selection } ?? 0
        if control.selectedSegmentIndex != idx {
            control.selectedSegmentIndex = idx
        }
        // Re-bake ONLY when the selection actually changed. Re-baking on every
        // update pass froze the app: setImage invalidates the control's
        // intrinsic size → SwiftUI re-runs layout/update → setImage again — a
        // main-thread layout feedback loop, fed continuously by item polling
        // re-renders (2026-07-14). The guard breaks the cycle.
        guard context.coordinator.lastBakedSelection != selection else { return }
        context.coordinator.lastBakedSelection = selection
        for (i, tab) in tabs.enumerated() {
            control.setImage(Self.cellImage(tab, highlighted: i == idx), forSegmentAt: i)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    /// Render the SwiftUI tab cell into an image the control can host.
    /// .alwaysOriginal keeps our baked-in colors (the control would otherwise
    /// template-tint everything).
    @MainActor
    static func cellImage(_ tab: GlassTabItem, highlighted: Bool) -> UIImage {
        let renderer = ImageRenderer(content: TabCellView(tab: tab, highlighted: highlighted))
        renderer.scale = UIScreen.main.scale
        return (renderer.uiImage ?? UIImage()).withRenderingMode(.alwaysOriginal)
    }

    final class Coordinator: NSObject {
        var parent: NativeSegmentedTabBar
        /// Selection the segment images were last rendered for — guards the
        /// updateUIView re-bake so it never runs on unrelated update passes.
        var lastBakedSelection: String?
        init(parent: NativeSegmentedTabBar) { self.parent = parent }

        @objc func changed(_ control: UISegmentedControl) {
            let idx = control.selectedSegmentIndex
            guard parent.tabs.indices.contains(idx) else { return }
            parent.selection = parent.tabs[idx].key
        }
    }
}
