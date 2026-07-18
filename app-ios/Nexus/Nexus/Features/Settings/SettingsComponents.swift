import SwiftUI

// MARK: - Native settings primitives (Bloom variant, locked 2026-07-18)
//
// We stopped hand-rolling card/row metrics. These are thin helpers over
// SwiftUI's native `List(.insetGrouped)` — so font, padding, row height and
// separators are iOS-native for free. Chosen via SettingsPlayground: native
// inset-grouped list on the lavender bloom background, plain ink line-icons.
//
// Usage:
//   NavigationStack {
//     ZStack { NexusBackground().ignoresSafeArea()
//       List { Section("App") { SettingsRow(icon:…, label:…) { SettingsValue(…) } } }
//         .nexusInsetGrouped()
//     }
//   }

extension View {
    /// iOS Settings-style inset-grouped list with a transparent scroll
    /// background (so the bloom behind it shows through). Pair with a
    /// `NexusBackground()` in a ZStack behind the List.
    func nexusInsetGrouped() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
    }
}

/// Leading line-icon for a settings row — ink (or destructive), 17pt, in a
/// fixed 29pt column so labels align. Matches native iOS list metrics.
struct SettingsIcon: View {
    let symbol: String
    var danger: Bool = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17))
            .foregroundStyle(danger ? Color.Nexus.destructive : Color.Nexus.ink)
            .frame(width: 29, alignment: .center)
    }
}

/// A settings row: icon + label + optional trailing accessory. Designed to
/// live inside a native `List`/`Section`, which supplies row height, padding
/// and separators. Wrap in `Button`/`NavigationLink` at the call site for taps.
struct SettingsRow<Trailing: View>: View {
    let icon: String
    let label: String
    var danger: Bool = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(symbol: icon, danger: danger)
            Text(label)
                .foregroundStyle(danger ? Color.Nexus.destructive : Color.Nexus.ink)
            Spacer(minLength: 8)
            trailing()
        }
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String, label: String, danger: Bool = false) {
        self.init(icon: icon, label: label, danger: danger) { EmptyView() }
    }
}

/// Right-aligned secondary value text (iOS list "detail" grey).
struct SettingsValue: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

/// Trailing "opens externally" arrow (for Terms / Privacy web links).
struct SettingsExternalArrow: View {
    var body: some View {
        Image(systemName: "arrow.up.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}

/// Manual disclosure chevron for tappable rows that aren't NavigationLinks yet
/// (e.g. Subscription — no destination screen built).
struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}
