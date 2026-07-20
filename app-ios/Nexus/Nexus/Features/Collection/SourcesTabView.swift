import SwiftUI

// MARK: - Sources tab
//
// Full list of saved sources for a Collection.
// Features:
//   • Content-type icon badge (article/podcast/video/thread/blog/announcement)
//   • Tag chips row (up to 6, horizontally scrollable) — see TagChip below
//   • Swipe-to-delete with native List .onDelete / .swipeActions
//   • Pull-to-refresh via List .refreshable
//
// Design: DESIGN_LANGUAGE §4 (list rows), §7 (cards + hairline border).

struct SourcesTabView: View {
    // Items + state are owned by CollectionViewModel (single source of truth).
    let items: [Item]
    let isLoading: Bool
    let collectionId: UUID
    /// Optional load error forwarded from CollectionViewModel.
    var error: APIError? = nil
    /// Called when the user commits a swipe-to-delete gesture.
    let onDelete: (Item) async -> Void
    /// Called when the user pulls to refresh.
    let onRefresh: () async -> Void

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                LoadingStateView()
            } else if let apiError = error, items.isEmpty {
                VStack {
                    Spacer()
                    ErrorStateView(
                        message: apiError.errorDescription ?? "Couldn't load sources."
                    ) {
                        await onRefresh()
                    }
                    Spacer()
                }
            } else if items.isEmpty {
                emptyState
            } else {
                sourcesList
            }
        }
        // navigationDestination for ItemDetailRoute is registered in CollectionView
        // (always present) — not here, since this tab unmounts when you switch tabs,
        // which left the source→reader link dead (#10).
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "doc.text.magnifyingglass",
                title: "No sources yet",
                subtitle: "Add a source to start building this collection."
            )
            Spacer()
        }
    }

    // MARK: - Sources list
    //
    // Uses List + .swipeActions for native iOS feel:
    //   - Swipe trailing edge → red "Delete" action
    //   - .refreshable → pull-to-refresh spinner at system level
    //
    // LazyVStack inside ScrollView was considered (gives more layout control) but
    // List + .swipeActions is the only way to get fully native swipe-to-delete
    // behaviour (rubber-band physics, haptics, accessibility) without third-party code.

    private var sourcesList: some View {
        List {
            ForEach(items) { item in
                NavigationLink(value: ItemDetailRoute(item: item, collectionId: collectionId)) {
                    SourceCard(item: item)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(
                    top: NexusSpacing.xs,
                    leading: NexusSpacing.sideGutter,
                    bottom: NexusSpacing.xs,
                    trailing: NexusSpacing.sideGutter
                ))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.Nexus.pageBackground)
                // MARK: Swipe-to-delete
                // Trailing swipe reveals a destructive Delete button.
                // The role: .destructive colours it red automatically; the label
                // uses the "trash" icon + "Delete" text per Apple HIG.
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task { await onDelete(item) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Color.Nexus.pageBackground)
        .scrollContentBackground(.hidden)
        // MARK: Pull-to-refresh
        // .refreshable uses the system spinner + async/await.
        // It blocks the gesture until onRefresh completes, so the spinner
        // stays visible for the full network round-trip.
        .refreshable {
            await onRefresh()
        }
    }
}

// MARK: - Source card
//
// Full-width card for one saved source.
// Layout:
//   [icon-badge]  [title ·············] [status pill]
//                 [domain overline]
//
//   [summary — up to 3 lines, only when completed]
//
//   [tag] [tag] [tag] → horizontally scrollable (up to 6)

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

    // MARK: Header row — icon badge + title + status pill

    private var headerRow: some View {
        HStack(alignment: .top, spacing: NexusSpacing.md) {
            ContentTypeIconBadge(contentType: item.contentType)

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

    // MARK: Summary section

    @ViewBuilder
    private var summarySection: some View {
        if item.ingestStatus == .completed, let summary = item.summary {
            Text(summary)
                .font(.Nexus.bodySmall)
                .foregroundColor(.Nexus.muted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        } else if item.ingestStatus == .processing {
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

    // MARK: Tags section — horizontally scrollable chip row

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

// MARK: - Content-type icon badge
//
// Tinted 28×28 rounded-square badge. Each content family gets its own
// background + foreground tint so the badge communicates content type at a
// glance without relying solely on the icon shape.
// Tint palette mirrors the JSX prototype (collection-view.jsx, ICON_TINT).

private struct ContentTypeIconBadge: View {
    let contentType: Item.ContentType

    var body: some View {
        Image(systemName: contentType.icon)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(foregroundColor)
            .frame(width: 28, height: 28)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xs))
    }

    // Tint palette: one faint bg + one fg per content family.
    // Intentionally distinct from the brand accent to avoid overuse of plum.
    private var backgroundColor: Color {
        switch contentType {
        case .article:      return Color(hex: "#EEF3FB") // cool-blue wash
        case .blog:         return Color(hex: "#EEF3FB") // same family as article
        case .podcast:      return Color(hex: "#EEF3FB") // audio — cool blue wash
        case .video:        return Color(hex: "#FCF0EE") // warm-red wash
        case .youtube:      return Color(hex: "#FCF0EE") // same family
        case .thread:       return Color(hex: "#F0F7EE") // sage-green wash
        case .announcement: return Color(hex: "#FDF5E8") // amber wash
        case .other:        return Color.Nexus.surface2
        }
    }

    private var foregroundColor: Color {
        switch contentType {
        case .article:      return Color(hex: "#4A7ABB") // cool blue
        case .blog:         return Color(hex: "#4A7ABB")
        case .podcast:      return Color(hex: "#4A7ABB")
        case .video:        return Color(hex: "#B84C3A") // warm red
        case .youtube:      return Color(hex: "#B84C3A")
        case .thread:       return Color(hex: "#4A8A5C") // sage green
        case .announcement: return Color(hex: "#B8862A") // amber
        case .other:        return Color.Nexus.faint
        }
    }
}

// MARK: - Ingest status pill

private struct IngestStatusPill: View {
    let status: Item.IngestStatus

    var body: some View {
        // .completed is the normal steady state — no pill (keeps cards clean)
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
// Public so other views (e.g. SearchView) can reuse.

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
