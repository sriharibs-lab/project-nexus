import SwiftUI

// MARK: - Infographic v2 (native, data-driven, themed)
//
// Renders the backend's grounded spec natively — crisp type, real numbers, no
// AI-image garbling. v2 (feedback 2026-10-09 "bare and devoid of creativity"):
// a themed header band with the piece's icon, an optional HERO figure, icon
// tiles with proportional bars, a gradient timeline spine with icon nodes,
// a comparison grid that highlights the stronger side, and a takeaway line.
// The same InfographicCard is used in the detail sheet AND rendered to an
// image for "Share as image" (ImageRenderer), so what you share is what you see.

/// Five restrained two-stop palettes. The model picks the one that fits the
/// subject's mood; "ember" is the brand gradient.
struct InfoTheme {
    let name: String
    let stops: [Color]
    let tint: Color          // single accent for numbers/bars/dots
    let onBand: Color        // text on the header band

    static func named(_ raw: String?) -> InfoTheme {
        switch raw {
        case "plum":   return InfoTheme(name: "plum",   stops: [Color(hex: "#5B3F97"), Color(hex: "#8B6AC9")], tint: Color(hex: "#7054AB"), onBand: .white)
        case "ocean":  return InfoTheme(name: "ocean",  stops: [Color(hex: "#1F5A86"), Color(hex: "#3F93BF")], tint: Color(hex: "#2F7BA8"), onBand: .white)
        case "forest": return InfoTheme(name: "forest", stops: [Color(hex: "#1F5E44"), Color(hex: "#4E9A72")], tint: Color(hex: "#2F7A58"), onBand: .white)
        case "amber":  return InfoTheme(name: "amber",  stops: [Color(hex: "#9A6A14"), Color(hex: "#D9A23C")], tint: Color(hex: "#B8862A"), onBand: .white)
        default:       return InfoTheme(name: "ember",  stops: [Color(hex: "#6A4DA8"), Color(hex: "#B8569C"), Color(hex: "#E8776A")], tint: Color(hex: "#9A5BB5"), onBand: .white)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    var spine: LinearGradient {
        LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
    }
}

struct InfographicCard: View {
    let title: String
    let subtitle: String?
    let content: ArtifactContent
    var collectionName: String? = nil

    private var theme: InfoTheme { InfoTheme.named(content.theme) }
    private var symbol: String { content.icon ?? "sparkles" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            band
            VStack(alignment: .leading, spacing: 18) {
                if let hero = content.hero, !hero.value.isEmpty { heroBlock(hero) }
                switch content.layout {
                case "timeline":   timeline
                case "comparison": comparison
                default:           numbers
                }
                if let t = content.takeaway, !t.isEmpty { takeaway(t) }
                footer
            }
            .padding(18)
        }
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.Nexus.hair, lineWidth: 1))
        .shadow(color: theme.tint.opacity(0.16), radius: 18, y: 8)
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }

    // MARK: Header band — themed gradient, icon tile, eyebrow, title

    private var band: some View {
        ZStack(alignment: .topLeading) {
            theme.gradient
            // Soft radial highlight so the band has depth, not a flat fill.
            RadialGradient(colors: [.white.opacity(0.22), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
            // Large ghost glyph, bottom-right — the piece's subject at a glance.
            Image(systemName: symbol)
                .font(.system(size: 96, weight: .bold))
                .foregroundColor(.white.opacity(0.10))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 14, y: 18)
                .clipped()

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.stops.first ?? theme.tint)
                        .frame(width: 26, height: 26)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(eyebrow)
                        .font(.system(size: 10.5, weight: .bold)).kerning(1.2)
                        .foregroundColor(theme.onBand.opacity(0.85))
                        .lineLimit(1)
                }
                Text(title)
                    .font(.system(size: 23, weight: .bold)).kerning(-0.5)
                    .foregroundColor(theme.onBand)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(theme.onBand.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
            }
            .padding(18)
            .padding(.trailing, 28)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var eyebrow: String {
        if let c = collectionName, !c.isEmpty { return "INFOGRAPHIC · " + c.uppercased() }
        return "INFOGRAPHIC"
    }

    // MARK: Hero — the one figure that matters

    private func heroBlock(_ hero: InfoHero) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(hero.value)
                .font(.system(size: 46, weight: .heavy, design: .rounded)).kerning(-1.6)
                .foregroundStyle(theme.gradient)
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(hero.label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.Nexus.muted)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
        }
        .padding(.bottom, 2)
    }

    // MARK: Numbers — icon tiles with proportional bars

    private var numbers: some View {
        let items = content.numbers ?? []
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(items.indices, id: \.self) { i in
                let n = items[i]
                VStack(alignment: .leading, spacing: 7) {
                    Image(systemName: n.icon ?? "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(theme.tint)
                        .frame(width: 24, height: 24)
                        .background(theme.tint.opacity(0.12))
                        .clipShape(Circle())
                    Text(n.value)
                        .font(.system(size: 27, weight: .bold, design: .rounded)).kerning(-0.7)
                        .foregroundColor(.Nexus.ink)
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.55)
                    Text(n.label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.Nexus.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                    if let pct = n.pct {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.tint.opacity(0.14))
                                Capsule().fill(theme.gradient)
                                    .frame(width: max(6, geo.size.width * CGFloat(min(max(pct, 0), 100)) / 100))
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 2)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                .background(Color.Nexus.surface2.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: Timeline — gradient spine with icon nodes

    private var timeline: some View {
        let items = content.timeline ?? []
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    Text(items[i].when)
                        .font(.system(size: 12, weight: .bold)).monospacedDigit()
                        .foregroundColor(theme.tint)
                        .frame(width: 58, alignment: .trailing)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.top, 6)
                    VStack(spacing: 0) {
                        Rectangle().fill(i == 0 ? AnyShapeStyle(.clear) : AnyShapeStyle(theme.spine)).frame(width: 2, height: 4)
                        ZStack {
                            Circle().fill(theme.gradient).frame(width: 24, height: 24)
                            Image(systemName: items[i].icon ?? "circle.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Rectangle().fill(i == items.count - 1 ? AnyShapeStyle(.clear) : AnyShapeStyle(theme.spine))
                            .frame(width: 2).frame(maxHeight: .infinity)
                    }
                    .frame(width: 24)
                    Text(items[i].what)
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(.Nexus.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5)
                        .padding(.bottom, i == items.count - 1 ? 0 : 18)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Comparison — two columns, stronger side highlighted

    private var comparison: some View {
        let comp = content.comparison
        let rows = comp?.rows ?? []
        let colA = theme.stops.first ?? theme.tint
        let colB = theme.stops.last ?? theme.tint
        return VStack(alignment: .leading, spacing: 0) {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 0) {
                GridRow {
                    Text("").frame(width: 74, alignment: .leading)
                    pill(comp?.a ?? "A", color: colA)
                    pill(comp?.b ?? "B", color: colB)
                }
                .padding(.bottom, 10)
                ForEach(rows.indices, id: \.self) { i in
                    Divider().overlay(Color.Nexus.hair)
                    GridRow(alignment: .top) {
                        Text(rows[i].aspect)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.Nexus.muted)
                            .frame(width: 74, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 10)
                        cell(rows[i].a, highlighted: rows[i].edge == "a", color: colA)
                        cell(rows[i].b, highlighted: rows[i].edge == "b", color: colB)
                    }
                }
            }
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(color)
            .clipShape(Capsule())
    }

    private func cell(_ text: String, highlighted: Bool, color: Color) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Text(text)
                .font(.system(size: 13.5, weight: highlighted ? .semibold : .regular))
                .foregroundColor(.Nexus.ink)
                .fixedSize(horizontal: false, vertical: true)
            if highlighted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 8)
        .background(highlighted ? color.opacity(0.10) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.vertical, 3)
    }

    // MARK: Takeaway + footer

    private func takeaway(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(theme.gradient).frame(width: 3)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .serif).italic())
                .foregroundColor(.Nexus.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            EchoMark(color: .Nexus.faint, size: 14)
            Text("Made with Nexus")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.Nexus.faint)
            Spacer()
            Text("Every figure from your sources")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.Nexus.ghost)
        }
    }
}

/// Detail-sheet content: the card, scrollable, on the page background.
struct InfographicView: View {
    let artifact: Artifact
    var collectionName: String? = nil
    var body: some View {
        ScrollView {
            if let content = artifact.content {
                InfographicCard(title: content.title ?? artifact.title, subtitle: content.subtitle,
                                content: content, collectionName: collectionName)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
            }
        }
    }
}

#if DEBUG
enum InfographicPreview {
    static func sample(layout: String) -> ArtifactContent {
        var c = ArtifactContent()
        c.layout = layout
        c.title = "Picasso, in numbers"
        c.subtitle = "The scale of a seventy-year career, from Málaga to Mougins."
        c.theme = "ember"
        c.icon = "paintpalette.fill"
        c.takeaway = "Volume was the method: Picasso treated every canvas as a draft of the next."
        switch layout {
        case "timeline":
            c.title = "A life in five moves"
            c.theme = "plum"
            c.hero = nil
            c.timeline = [
                .init(when: "1881", what: "Born in Málaga; paints his first canvas at eight.", icon: "star.fill"),
                .init(when: "1901", what: "The Blue Period begins after a friend's death.", icon: "drop.fill"),
                .init(when: "1907", what: "Les Demoiselles d'Avignon breaks with perspective.", icon: "bolt.fill"),
                .init(when: "1937", what: "Guernica, painted in six weeks for the Paris Expo.", icon: "flag.fill"),
                .init(when: "1973", what: "Dies at 91 in Mougins, still painting.", icon: "moon.fill"),
            ]
        case "comparison":
            c.title = "Blue Period vs Rose Period"
            c.theme = "ocean"
            c.icon = "paintpalette.fill"
            c.comparison = .init(a: "Blue (1901–04)", b: "Rose (1904–06)", rows: [
                .init(aspect: "Mood", a: "Melancholy, poverty", b: "Warmth, tenderness", edge: nil),
                .init(aspect: "Palette", a: "Cold blues, greens", b: "Pinks, ochres, earth", edge: nil),
                .init(aspect: "Subjects", a: "Beggars, outcasts", b: "Circus performers", edge: nil),
                .init(aspect: "Market today", a: "Rarer, pricier", b: "More plentiful", edge: "a"),
            ])
        default:
            c.hero = .init(value: "50,000+", label: "works across paintings, sculpture, ceramics and prints")
            c.numbers = [
                .init(value: "91", label: "years lived", icon: "hourglass", pct: nil),
                .init(value: "4", label: "major periods", icon: "paintpalette.fill", pct: nil),
                .init(value: "1,885", label: "paintings", icon: "photo.fill", pct: 100),
                .init(value: "1,228", label: "sculptures", icon: "cube.fill", pct: 65),
                .init(value: "2,880", label: "ceramics", icon: "circle.hexagongrid.fill", pct: 100),
                .init(value: "12,000", label: "drawings", icon: "pencil", pct: 100),
            ]
        }
        return c
    }

    @MainActor static func make(layout: String) -> some View {
        let c = sample(layout: layout)
        return NavigationStack {
            ZStack {
                Color.Nexus.pageBackground.ignoresSafeArea()
                ScrollView {
                    InfographicCard(title: c.title!, subtitle: c.subtitle, content: c, collectionName: "Picasso")
                        .padding(.horizontal, 16).padding(.top, 12)
                }
            }
            .navigationTitle("Infographic").navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
