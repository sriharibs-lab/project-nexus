import SwiftUI

// MARK: - Settings Playground
//
// Stop hand-rolling card metrics. SwiftUI's native `List(.insetGrouped)` gives
// iOS Settings' exact font, padding, row height, separators, and menu anchoring
// for free. This screen shows 3 native variants so Srihari can pick on device
// (like Glass Playground). The winner ports to Settings + Account + Feedback.
//
//   • iOS    — pure inset-grouped, system grouped background, plain mono icons
//   • Bloom  — native metrics on our lavender bloom background, ink icons
//   • Tiles  — native, iOS-Settings colored rounded-square icon tiles
//
// Launch: simctl launch app.nexus -preview settingsplayground [-variant 0|1|2]

struct SettingsPlaygroundView: View {
    enum Variant: Int, CaseIterable, Identifiable {
        case ios, bloom, tiles
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .ios:   return "iOS"
            case .bloom: return "Bloom"
            case .tiles: return "Tiles"
            }
        }
    }

    @State var variant: Variant = .ios
    @AppStorage("nx_appearance") private var appearance = "Light"

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                settingsList
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Variant", selection: $variant) {
                        ForEach(Variant.allCases) { v in Text(v.label).tag(v) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
        }
    }

    // MARK: Background per variant

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .bloom: NexusBackground()
        default:     Color(.systemGroupedBackground)
        }
    }

    // MARK: The native list (shared structure, variant-styled rows)

    private var settingsList: some View {
        List {
            Section("App") {
                appearanceRow
            }

            Section("Data") {
                NavigationLink {
                    Text("Offline reading cache detail")
                } label: {
                    row("Offline reading cache", "internaldrive", tile: .blue) {
                        Text("Empty").foregroundStyle(.secondary)
                    }
                }
            }

            Section("About") {
                row("Version", "info.circle", tile: .gray) {
                    Text("1.0 (1)").foregroundStyle(.secondary)
                }
                Button {} label: {
                    row("Terms of Service", "doc.text", tile: .gray) {
                        Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
                Button {} label: {
                    row("Privacy Policy", "hand.raised", tile: .blue) {
                        Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
            }

            Section("Developer") {
                row("Build stamp", "sparkle", tile: .purple) {
                    Text("Jul 18 12:39").foregroundStyle(.secondary)
                }
                NavigationLink {
                    Text("Glass Playground")
                } label: {
                    row("Glass Playground", "circle.hexagongrid", tile: .indigo) { EmptyView() }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(variant == .bloom ? .hidden : .automatic)
    }

    // MARK: Appearance row (native Menu — anchors right, no centered-popover bug)

    private var appearanceRow: some View {
        row("Appearance", "circle.lefthalf.filled", tile: .gray) {
            Menu {
                Button { appearance = "Light" } label: { Label("Light", systemImage: "checkmark") }
                Button {} label: { Text("Dark") }.disabled(true)
                Button {} label: { Text("System") }.disabled(true)
            } label: {
                HStack(spacing: 3) {
                    Text(appearance).foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Row builder (native metrics; only the leading icon changes)

    @ViewBuilder
    private func row<Trailing: View>(
        _ label: String,
        _ symbol: String,
        tile: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            leadingIcon(symbol, tile: tile)
            Text(label)
            Spacer(minLength: 8)
            trailing()
        }
    }

    @ViewBuilder
    private func leadingIcon(_ symbol: String, tile: Color) -> some View {
        switch variant {
        case .tiles:
            // iOS Settings-app colored rounded-square tile
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tile))
        case .bloom:
            // Ink line icon on the bloom bg
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(Color.Nexus.ink)
                .frame(width: 29, alignment: .center)
        case .ios:
            // Plain monochrome symbol, iOS-list default sizing
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
                .frame(width: 29, alignment: .center)
        }
    }
}

#if DEBUG
#Preview { SettingsPlaygroundView() }
#endif
