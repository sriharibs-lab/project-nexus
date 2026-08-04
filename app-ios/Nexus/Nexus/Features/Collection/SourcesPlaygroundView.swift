import SwiftUI

// MARK: - Sources redesign playground (2026-08-03)
//
// The shipped Sources list (tall cards + right chevron) reads weak. Three
// cleaner directions to pick from — all kill the disclosure arrow and tighten
// the hierarchy. Launch: simctl launch app.nexus -preview sourcesplayground [-variant 0|1|2]

struct SourcesPlaygroundView: View {
    enum Variant: Int, CaseIterable, Identifiable {
        case compact, card, media
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .compact: return "Compact"
            case .card:    return "Card"
            case .media:   return "Media"
            }
        }
    }

    @State var variant: Variant = .compact

    var body: some View {
        NavigationStack {
            ZStack {
                NexusBackground().ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: variant == .compact ? 0 : 12) {
                        ForEach(Array(Self.samples.enumerated()), id: \.offset) { i, s in
                            switch variant {
                            case .compact: CompactRow(source: s, showDivider: i < Self.samples.count - 1)
                            case .card:    CleanCard(source: s)
                            case .media:   MediaRow(source: s)
                            }
                        }
                    }
                    .padding(.horizontal, variant == .compact ? NexusSpacing.sideGutter : NexusSpacing.sideGutter)
                    .padding(.top, 8)
                }
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

    // MARK: Sample data
    struct Source {
        let title: String, domain: String, type: SourceType, summary: String, tags: [String]
    }
    enum SourceType {
        case article, video, podcast
        var icon: String {
            switch self { case .article: return "doc.text"; case .video: return "play.rectangle.fill"; case .podcast: return "waveform" }
        }
        var label: String {
            switch self { case .article: return "Article"; case .video: return "Video"; case .podcast: return "Podcast" }
        }
        var tint: Color {
            switch self { case .article: return Color(hex: "#4A7ABB"); case .video: return Color(hex: "#B84C3A"); case .podcast: return Color(hex: "#7B57B0") }
        }
        var wash: Color {
            switch self { case .article: return Color(hex: "#EEF3FB"); case .video: return Color(hex: "#FCF0EE"); case .podcast: return Color(hex: "#F3EFFA") }
        }
    }

    static let samples: [Source] = [
        .init(title: "Watch House of the Dragon", domain: "hbo.com", type: .article,
              summary: "Season 3 is now streaming — a Game of Thrones prequel set 200 years earlier exploring House Targaryen at its height.",
              tags: ["hbo-max", "game-of-thrones"]),
        .init(title: "House of the Dragon", domain: "en.wikipedia.org", type: .article,
              summary: "A Game of Thrones prequel spanning three seasons (2022–2026), adapting Martin's Targaryen civil war.",
              tags: ["television-series", "fantasy-adaptation"]),
        .init(title: "The Dance of the Dragons, explained", domain: "youtube.com", type: .video,
              summary: "A deep-dive video essay on the Targaryen succession war and the key players who tore the realm apart.",
              tags: ["lore", "explainer"]),
        .init(title: "Fire & Blood", domain: "en.wikipedia.org", type: .article,
              summary: "George R.R. Martin's fictional history of House Targaryen, the source material for the series.",
              tags: ["george-r-r-martin", "fantasy-fiction"]),
        .init(title: "House of the Dragon reviews", domain: "rottentomatoes.com", type: .article,
              summary: "Critic and audience scores plus streaming availability for the fantasy drama.",
              tags: ["reviews", "ratings"]),
    ]
}

// MARK: - Variant 1 · Compact (dense, scannable list)

private struct CompactRow: View {
    let source: SourcesPlaygroundView.Source
    let showDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: source.type.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(source.type.tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                        .font(.system(size: 15.5, weight: .semibold))
                        .kerning(-0.2)
                        .foregroundColor(.Nexus.ink)
                        .lineLimit(1)
                    Text("\(source.domain) · \(source.type.label)")
                        .font(.system(size: 12.5))
                        .foregroundColor(.Nexus.faint)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            if showDivider {
                Rectangle().fill(Color.Nexus.hair).frame(height: NexusBorder.hair)
                    .padding(.leading, 34)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Variant 2 · Clean card (refined, no chevron)

private struct CleanCard: View {
    let source: SourcesPlaygroundView.Source

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: source.type.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(source.type.tint)
                    .frame(width: 22, height: 22)
                    .background(source.type.wash)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(source.title)
                    .font(.system(size: 16, weight: .semibold))
                    .kerning(-0.3)
                    .foregroundColor(.Nexus.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(source.domain)
                    .font(.system(size: 12))
                    .foregroundColor(.Nexus.faint)
                    .lineLimit(1)
            }
            Text(source.summary)
                .font(.system(size: 13.5))
                .foregroundColor(.Nexus.muted)
                .lineSpacing(2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(source.tags, id: \.self) { tag in TagPill(tag) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.Nexus.border, lineWidth: NexusBorder.hair))
    }
}

// MARK: - Variant 3 · Media (prominent type tile, airy)

private struct MediaRow: View {
    let source: SourcesPlaygroundView.Source

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: source.type.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(source.type.tint)
                .frame(width: 44, height: 44)
                .background(source.type.wash)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(source.title)
                    .font(.system(size: 16, weight: .semibold))
                    .kerning(-0.3)
                    .foregroundColor(.Nexus.ink)
                    .lineLimit(2)
                Text("\(source.domain) · \(source.type.label)")
                    .font(.system(size: 12.5))
                    .foregroundColor(.Nexus.faint)
                Text(source.summary)
                    .font(.system(size: 13.5))
                    .foregroundColor(.Nexus.muted)
                    .lineSpacing(2)
                    .lineLimit(2)
                    .padding(.top, 1)
                HStack(spacing: 6) {
                    ForEach(source.tags, id: \.self) { tag in TagPill(tag) }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

private struct TagPill: View {
    let tag: String
    init(_ tag: String) { self.tag = tag }
    var body: some View {
        Text(tag)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(.Nexus.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.Nexus.surface2)
            .clipShape(Capsule())
    }
}

#if DEBUG
#Preview { SourcesPlaygroundView() }
#endif
