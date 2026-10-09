import SwiftUI

// MARK: - Infographic (native, data-driven)
//
// Renders the backend's grounded spec (numbers | timeline | comparison)
// natively — crisp text and real numbers, no AI-image garbling. The same
// InfographicCard is used in the detail sheet AND rendered to an image for
// "Share as image" (ImageRenderer), so what you share is exactly what you see.

struct InfographicCard: View {
    let title: String
    let subtitle: String?
    let content: ArtifactContent

    private var ember: LinearGradient {
        LinearGradient(colors: [Color(hex: "#7054AB"), Color(hex: "#B8569C"), Color(hex: "#E8776A")],
                       startPoint: .leading, endPoint: .trailing)
    }
    private var hairline: LinearGradient {
        LinearGradient(colors: [Color(hex: "#7054AB").opacity(0.16), Color(hex: "#E8776A").opacity(0.11)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("INFOGRAPHIC")
                    .font(.system(size: 10.5, weight: .bold)).kerning(1.3)
                    .foregroundColor(.Nexus.accent)
                Text(title)
                    .font(.system(size: 21, weight: .bold)).kerning(-0.4)
                    .foregroundColor(.Nexus.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13.5))
                        .foregroundColor(.Nexus.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            switch content.layout {
            case "timeline":   timeline
            case "comparison": comparison
            default:           numbers
            }

            HStack(spacing: 6) {
                EchoMark(color: .Nexus.faint, size: 14)
                Text("Made with Nexus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.Nexus.faint)
                Spacer()
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(hairline, lineWidth: 1))
        .shadow(color: Color(hex: "#5E3F9E").opacity(0.10), radius: 16, y: 7)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    // MARK: Numbers — 2-col grid of stat tiles

    private var numbers: some View {
        let items = content.numbers ?? []
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(items.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 5) {
                    Text(items[i].value)
                        .font(.system(size: 26, weight: .bold, design: .rounded)).kerning(-0.6)
                        .foregroundColor(.Nexus.ink)
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(items[i].label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.Nexus.faint)
                        .fixedSize(horizontal: false, vertical: true)
                    Capsule().fill(ember).frame(width: 36, height: 3).padding(.top, 4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                .background(Color.Nexus.surface2.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: Timeline — dated rows on a gradient spine

    private var timeline: some View {
        let items = content.timeline ?? []
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    Text(items[i].when)
                        .font(.system(size: 12.5, weight: .semibold)).monospacedDigit()
                        .foregroundColor(.Nexus.accent)
                        .frame(width: 60, alignment: .trailing)
                        .padding(.top, 2)
                    VStack(spacing: 0) {
                        Rectangle().fill(i == 0 ? Color.clear : Color.Nexus.border).frame(width: 2, height: 6)
                        Circle().fill(ember).frame(width: 10, height: 10)
                        Rectangle().fill(i == items.count - 1 ? Color.clear : Color.Nexus.border)
                            .frame(width: 2).frame(maxHeight: .infinity)
                    }
                    .frame(width: 12)
                    Text(items[i].what)
                        .font(.system(size: 14.5))
                        .foregroundColor(.Nexus.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, i == items.count - 1 ? 0 : 16)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Comparison — two columns with an aspect rail

    private var comparison: some View {
        let comp = content.comparison
        let rows = comp?.rows ?? []
        return VStack(alignment: .leading, spacing: 0) {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 0) {
                GridRow {
                    Text("").frame(width: 78, alignment: .leading)
                    pill(comp?.a ?? "A", color: Color(hex: "#7054AB"))
                    pill(comp?.b ?? "B", color: Color(hex: "#E8776A"))
                }
                .padding(.bottom, 10)
                ForEach(rows.indices, id: \.self) { i in
                    Divider().overlay(Color.Nexus.hair)
                    GridRow(alignment: .top) {
                        Text(rows[i].aspect)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.Nexus.muted)
                            .frame(width: 78, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        cell(rows[i].a)
                        cell(rows[i].b)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundColor(color)
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }

    private func cell(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13.5))
            .foregroundColor(.Nexus.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Detail-sheet content: the card, scrollable, on the page background.
struct InfographicView: View {
    let artifact: Artifact
    var body: some View {
        ScrollView {
            if let content = artifact.content {
                InfographicCard(title: content.title ?? artifact.title, subtitle: content.subtitle, content: content)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
        }
    }
}

#if DEBUG
enum InfographicPreview {
    @MainActor static func make(layout: String) -> some View {
        var c = ArtifactContent()
        c.layout = layout
        c.title = "Picasso — in numbers"
        c.subtitle = "The scale of a seventy-year career, from Málaga to Mougins."
        switch layout {
        case "timeline":
            c.title = "Picasso — a life in five moves"
            c.timeline = [
                .init(when: "1881", what: "Born in Málaga; paints his first canvas at 8."),
                .init(when: "1901", what: "The Blue Period begins after a friend's death."),
                .init(when: "1907", what: "Les Demoiselles d'Avignon breaks with perspective."),
                .init(when: "1937", what: "Guernica, painted in six weeks for the Paris Expo."),
                .init(when: "1973", what: "Dies at 91 in Mougins, still painting."),
            ]
        case "comparison":
            c.title = "Blue Period vs Rose Period"
            c.comparison = .init(a: "Blue (1901–04)", b: "Rose (1904–06)", rows: [
                .init(aspect: "Mood", a: "Melancholy, poverty", b: "Warmth, tenderness"),
                .init(aspect: "Palette", a: "Cold blues, greens", b: "Pinks, ochres, earth"),
                .init(aspect: "Subjects", a: "Beggars, outcasts", b: "Circus performers"),
                .init(aspect: "Trigger", a: "Casagemas' suicide", b: "Love, Fernande Olivier"),
            ])
        default:
            c.numbers = [
                .init(value: "91", label: "years lived"),
                .init(value: "50,000+", label: "works created"),
                .init(value: "1937", label: "Guernica painted"),
                .init(value: "4", label: "major periods"),
            ]
        }
        return NavigationStack {
            ZStack {
                Color.Nexus.pageBackground.ignoresSafeArea()
                ScrollView {
                    InfographicCard(title: c.title!, subtitle: c.subtitle, content: c)
                        .padding(.horizontal, 16).padding(.top, 12)
                }
            }
            .navigationTitle("Infographic").navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
