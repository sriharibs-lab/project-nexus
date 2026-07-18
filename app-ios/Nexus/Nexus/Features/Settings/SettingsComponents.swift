import SwiftUI

// MARK: - ChatGPT-style flat list primitives (locked 2026-07-16)
//
// White cards with NO border stroke (a whisper of shadow separates them from
// the lavender page), grey section labels, ink icon rows, inset hairline
// separators, values right-aligned. Shared by Account · Settings.

struct SettingsSectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .regular))
            .kerning(-0.2)
            .foregroundColor(.Nexus.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.bottom, 9)
    }
}

/// White rounded container, no border — a soft shadow reads it on the bloom bg.
/// Metrics tuned to ChatGPT iOS (2026-07-18).
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

enum SettingsRowTrailing {
    case chevron
    case external   // opens a browser link
    case none
}

struct SettingsRow: View {
    let icon: String
    let label: String
    var value: String? = nil
    var trailing: SettingsRowTrailing = .none
    var danger: Bool = false
    var showsDivider: Bool = true
    var action: (() -> Void)? = nil

    private var tint: Color { danger ? .Nexus.destructive : .Nexus.ink }

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 15) {
                    // ChatGPT-matched: thin line icon (.light reads like ChatGPT's
                    // line art, not SF Symbols' heavier regular), 20pt
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(tint)
                        .frame(width: 29, alignment: .center)

                    Text(label)
                        .font(.system(size: 17))
                        .kerning(-0.3)
                        .foregroundColor(danger ? .Nexus.destructive : .Nexus.ink)

                    Spacer(minLength: NexusSpacing.sm)

                    if let value {
                        Text(value)
                            .font(.system(size: 17))
                            .kerning(-0.3)
                            .foregroundColor(.Nexus.faint)
                            .lineLimit(1)
                    }
                    switch trailing {
                    case .chevron:
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.Nexus.ghost)
                    case .external:
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.Nexus.ghost)
                    case .none:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 17)
                .padding(.vertical, 17)   // taller rows — ChatGPT-spacious
                .contentShape(Rectangle())

                // inset separator — aligns under the label, ChatGPT-style
                if showsDivider {
                    Rectangle()
                        .fill(Color.Nexus.hair)
                        .frame(height: NexusBorder.hair)
                        .padding(.leading, 61)
                }
            }
        }
        .buttonStyle(SettingsRowStyle())
        .disabled(action == nil)
    }
}

private struct SettingsRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.black.opacity(0.04) : Color.clear)
    }
}
