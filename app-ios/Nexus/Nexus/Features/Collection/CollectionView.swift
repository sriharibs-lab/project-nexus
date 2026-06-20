import SwiftUI

// Navigation value for pushing ItemDetailView from the Sources list.
// Wrapped in a dedicated struct so it is Hashable without polluting Item.
struct ItemDetailRoute: Hashable {
    let item: Item
    let collectionId: UUID
}

struct CollectionView: View {
    @StateObject private var vm: CollectionViewModel
    @State private var selectedTab: Tab = .nexus

    enum Tab: String, CaseIterable {
        case nexus   = "Nexus"
        case sources = "Sources"
    }

    init(collection: NexusCollection) {
        _vm = StateObject(wrappedValue: CollectionViewModel(collection: collection))
    }

    var body: some View {
        ZStack {
            Color.Nexus.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                tabPicker
                    .padding(.horizontal, NexusSpacing.sideGutter)
                    .padding(.top, NexusSpacing.sm)
                    .padding(.bottom, NexusSpacing.xs)

                Rectangle()
                    .fill(Color.Nexus.hair)
                    .frame(height: NexusBorder.hair)

                tabContent
            }
        }
        .navigationTitle(vm.collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
    }

    // MARK: - Tab picker (pill capsule style per DESIGN_LANGUAGE §8)

    private var tabPicker: some View {
        HStack(spacing: NexusSpacing.xs) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(NexusAnimation.pivot) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.Nexus.labelMedium)
                        .kerning(NexusKerning.normal)
                        .foregroundColor(selectedTab == tab ? .Nexus.ink : .Nexus.muted)
                        .padding(.vertical, NexusSpacing.xs + 2)
                        .padding(.horizontal, NexusSpacing.md)
                        .background(
                            selectedTab == tab
                                ? Color.Nexus.surface2
                                : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .nexus:
            NexusTabView(collection: vm.collection)
                .transition(.opacity)
        case .sources:
            SourcesTabView(
                items: vm.items,
                isLoading: vm.isLoading,
                collectionId: vm.collection.id
            )
            .transition(.opacity)
        }
    }
}

// MARK: - Nexus tab (AI chat shell)

struct NexusTabView: View {
    let collection: NexusCollection

    var body: some View {
        VStack(spacing: NexusSpacing.lg) {
            Spacer()
            if let framing = collection.framingParagraph {
                Text(framing)
                    .font(.Nexus.bodyLarge)
                    .foregroundColor(.Nexus.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NexusSpacing.xl)
            } else {
                Text("Ask anything about your sources in \"\(collection.name)\".")
                    .font(.Nexus.bodyLarge)
                    .foregroundColor(.Nexus.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, NexusSpacing.xl)
            }
            Spacer()
        }
    }
}

// MARK: - Sources tab

struct SourcesTabView: View {
    let items: [Item]
    let isLoading: Bool
    let collectionId: UUID

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if items.isEmpty {
                VStack(spacing: NexusSpacing.sm) {
                    Spacer()
                    Text("No sources yet")
                        .font(.Nexus.labelLarge)
                        .foregroundColor(.Nexus.muted)
                    Text("Add a source to start building this collection.")
                        .font(.Nexus.caption)
                        .foregroundColor(.Nexus.ghost)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, NexusSpacing.xl)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: NexusSpacing.sm) {
                        ForEach(items) { item in
                            NavigationLink(value: ItemDetailRoute(item: item, collectionId: collectionId)) {
                                SourceCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, NexusSpacing.sideGutter)
                    .padding(.top, NexusSpacing.md)
                    .padding(.bottom, NexusSpacing.xl)
                }
            }
        }
        .navigationDestination(for: ItemDetailRoute.self) { route in
            ItemDetailView(item: route.item, collectionId: route.collectionId)
        }
    }
}

// MARK: - Source card
//
// Full-width card for one saved source.
// Layout:
//   [icon] [title ····················] [status pill]
//          [domain (overline)]
//
//   [summary preview — up to 3 lines, only when completed]
//
//   [tag] [tag] [tag] → scrollable

struct SourceCard: View {
    let item: Item

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.sm) {
            headerRow
            summarySection
            tagsSection
        }
        .padding(NexusSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.base)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
        )
        .scaleEffect(isPressed ? NexusScale.pressLight : 1)
        .animation(NexusAnimation.press, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(alignment: .top, spacing: NexusSpacing.md) {
            // Content type icon badge
            Image(systemName: item.contentType.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.Nexus.faint)
                .frame(width: 28, height: 28)
                .background(Color.Nexus.surface2)
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xs))

            // Title + domain
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top, spacing: NexusSpacing.sm) {
                    Text(item.title ?? item.url)
                        .font(.Nexus.labelMedium)
                        .foregroundColor(.Nexus.ink)
                        .lineLimit(2)
                        .kerning(NexusKerning.normal)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: NexusSpacing.xs)

                    IngestStatusPill(status: item.ingestStatus)
                }

                if let domain = extractDomain(from: item.url) {
                    Text(domain)
                        .font(.Nexus.overline)
                        .foregroundColor(.Nexus.ghost)
                        .kerning(NexusKerning.wide)
                        .textCase(.uppercase)
                }
            }
        }
    }

    // MARK: Summary

    @ViewBuilder
    private var summarySection: some View {
        if item.ingestStatus == .completed, let summary = item.summary {
            Text(summary)
                .font(.Nexus.bodySmall)
                .foregroundColor(.Nexus.muted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        } else if item.ingestStatus == .processing {
            // Subtle shimmer placeholder while AI processes
            HStack(spacing: NexusSpacing.xs) {
                Circle()
                    .fill(Color.Nexus.accent.opacity(0.6))
                    .frame(width: 5, height: 5)
                Text("AI processing…")
                    .font(.Nexus.caption)
                    .foregroundColor(.Nexus.ghost)
            }
        }
    }

    // MARK: Tags

    @ViewBuilder
    private var tagsSection: some View {
        if !item.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NexusSpacing.xs) {
                    ForEach(item.tags.prefix(6), id: \.self) { tag in
                        TagChip(label: tag)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: Helpers

    private func extractDomain(from urlString: String) -> String? {
        guard let host = URL(string: urlString)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

// MARK: - Ingest status pill

private struct IngestStatusPill: View {
    let status: Item.IngestStatus

    var body: some View {
        // Completed is the normal state — no pill needed (keeps cards clean)
        if status != .completed {
            HStack(spacing: 4) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 5, height: 5)
                Text(pillLabel)
                    .font(.Nexus.overline)
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, NexusSpacing.sm)
            .padding(.vertical, 3)
            .background(pillBackground)
            .clipShape(Capsule())
        }
    }

    private var pillLabel: String {
        switch status {
        case .pending:    return "Queued"
        case .processing: return "Processing"
        case .failed:     return "Failed"
        case .completed:  return ""
        }
    }

    private var dotColor: Color {
        switch status {
        case .pending:    return .Nexus.ghost
        case .processing: return .Nexus.accent
        case .failed:     return Color(hex: "#C0392B")
        case .completed:  return .Nexus.ghost
        }
    }

    private var textColor: Color { dotColor }

    private var pillBackground: Color {
        switch status {
        case .pending:    return Color.Nexus.surface2
        case .processing: return Color.Nexus.bloom.opacity(0.5)
        case .failed:     return Color(hex: "#C0392B").opacity(0.08)
        case .completed:  return Color.clear
        }
    }
}

// MARK: - Tag chip
// Public so HomeView can reuse if needed.

struct TagChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.Nexus.overline)
            .foregroundColor(.Nexus.muted)
            .kerning(NexusKerning.tight)
            .padding(.horizontal, NexusSpacing.sm)
            .padding(.vertical, 3)
            .background(Color.Nexus.surface2)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.Nexus.hair, lineWidth: NexusBorder.hair)
            )
    }
}
