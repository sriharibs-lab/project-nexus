import SwiftUI

// MARK: - Sources redesign playground v2 (2026-08-14)
//
// Round 1 (borderless "Media") read unfinished — and the List's NavigationLink
// re-added a system chevron. Round 2: elevated, native-feeling directions with
// real shadows + rounded corners + type icons, and NO stray chevron.
// Launch: simctl launch app.nexus -preview sourcesplayground [-variant 0|1|2]

struct SourcesPlaygroundView: View {
    enum Variant: Int, CaseIterable, Identifiable {
        case elevated, grouped, compact
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .elevated: return "Elevated"
            case .grouped:  return "Grouped"
            case .compact:  return "Compact"
            }
        }
    }

    @State var variant: Variant = .elevated

    var body: some View {
        NavigationStack {
            ZStack {
                NexusBackground().ignoresSafeArea()
                content
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

    @ViewBuilder
    private var content: some View {
        switch variant {
        case .elevated:
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(Self.samples.enumerated()), id: \.offset) { _, s in
                        ElevatedCard(source: s)
                    }
                }
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.top, 10)
            }
        case .grouped:
            List {
                Section {
                    ForEach(Array(Self.samples.enumerated()), id: \.offset) { _, s in
                        GroupedRow(source: s)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        case .compact:
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(Array(Self.samples.enumerated()), id: \.offset) { _, s in
                        CompactCard(source: s)
                    }
                }
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.top, 10)
            }
        }
    }

    // MARK: Sample data (matches the user's real tsunami collection)
    enum Status { case completed, failed }
    struct Source {
        let title: String, domain: String, type: SourceType, summary: String, tags: [String], status: Status
    }
    enum SourceType {
        case article, video
        var icon: String { self == .article ? "doc.text.fill" : "play.rectangle.fill" }
        var label: String { self == .article ? "Article" : "Video" }
        var tint: Color { self == .article ? Color(hex: "#4A7ABB") : Color(hex: "#B84C3A") }
        var wash: Color { self == .article ? Color(hex: "#EEF3FB") : Color(hex: "#FCF0EE") }
    }

    static let samples: [Source] = [
        .init(title: "National Weather Service — Tsunami Hazards", domain: "tsunami.gov", type: .article,
              summary: "The U.S. Tsunami Warning System provides real-time earthquake monitoring, tsunami alerts, and coastal guidance.",
              tags: ["tsunami-warning-system", "natural-disaster-alert"], status: .completed),
        .init(title: "M 4.7 — Pacific-Antarctic Ridge", domain: "earthquake.usgs.gov", type: .article,
              summary: "Magnitude 4.7 earthquake struck the Pacific-Antarctic Ridge on March 28 at 10 km depth.",
              tags: ["earthquake", "seismology", "mid-ocean-ridge"], status: .completed),
        .init(title: "Magnitude 7.7 earthquake strikes Indonesia", domain: "reuters.com", type: .article,
              summary: "Breaking coverage of the 7.7 quake off Indonesia and the tsunami warnings that followed.",
              tags: ["breaking-news", "indonesia"], status: .failed),
        .init(title: "How tsunamis form, explained", domain: "youtube.com", type: .video,
              summary: "A short video essay on how undersea earthquakes displace water and generate tsunami waves.",
              tags: ["explainer", "geology"], status: .completed),
        .init(title: "USGS Fact Sheet: Tsunami Hazards — A National Threat", domain: "pubs.usgs.gov", type: .article,
              summary: "The 2004 Indian Ocean tsunami killed 200,000+ and exposed critical gaps in warning systems.",
              tags: ["tsunami-hazards", "disaster-preparedness"], status: .completed),
    ]
}

// MARK: - Shared type tile

private struct TypeTile: View {
    let type: SourcesPlaygroundView.SourceType
    var size: CGFloat = 38
    var body: some View {
        Image(systemName: type.icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundColor(type.tint)
            .frame(width: size, height: size)
            .background(type.wash)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

private struct StatusOrMeta: View {
    let source: SourcesPlaygroundView.Source
    var body: some View {
        HStack(spacing: 7) {
            Text("\(source.domain) · \(source.type.label)")
                .font(.system(size: 12.5))
                .foregroundColor(.Nexus.faint)
                .lineLimit(1)
            if source.status == .failed {
                HStack(spacing: 4) {
                    Circle().fill(Color.Nexus.destructive).frame(width: 5, height: 5)
                    Text("Failed").font(.system(size: 11.5, weight: .medium)).foregroundColor(.Nexus.destructive)
                }
            }
        }
    }
}

private struct TagRow: View {
    let tags: [String]
    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags.prefix(3), id: \.self) { t in
                Text(t)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.Nexus.muted)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.Nexus.surface2)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Variant 1 · Elevated card (shadow + rounded + full info)

private struct ElevatedCard: View {
    let source: SourcesPlaygroundView.Source
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TypeTile(type: source.type, size: 38)
            VStack(alignment: .leading, spacing: 5) {
                Text(source.title)
                    .font(.system(size: 16, weight: .semibold)).kerning(-0.3)
                    .foregroundColor(.Nexus.ink).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                StatusOrMeta(source: source)
                Text(source.summary)
                    .font(.system(size: 13.5)).foregroundColor(.Nexus.muted)
                    .lineSpacing(2).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                TagRow(tags: source.tags).padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Variant 2 · Native inset-grouped list row

private struct GroupedRow: View {
    let source: SourcesPlaygroundView.Source
    var body: some View {
        HStack(spacing: 12) {
            TypeTile(type: source.type, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                    .font(.system(size: 15.5, weight: .semibold)).kerning(-0.2)
                    .foregroundColor(.Nexus.ink).lineLimit(2)
                StatusOrMeta(source: source)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .listRowBackground(Color.Nexus.cardBackground)
    }
}

// MARK: - Variant 3 · Compact elevated card (shadow, denser, no summary)

private struct CompactCard: View {
    let source: SourcesPlaygroundView.Source
    var body: some View {
        HStack(spacing: 12) {
            TypeTile(type: source.type, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(source.title)
                    .font(.system(size: 15.5, weight: .semibold)).kerning(-0.2)
                    .foregroundColor(.Nexus.ink).lineLimit(1)
                StatusOrMeta(source: source)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 7, x: 0, y: 2)
    }
}

#if DEBUG
#Preview { SourcesPlaygroundView() }
#endif
