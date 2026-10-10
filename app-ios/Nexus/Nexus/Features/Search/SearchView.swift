import Combine
import SwiftUI

// MARK: - SearchView
//
// Full-screen search experience. Launched as a sheet from HomeView's toolbar.
//
// Layout:
//   ┌──────────────────────────────────────────┐
//   │  [Search bar with live debounced input]   │
//   │  [Mode pill: Hybrid | Sources | Semantic] │  ← optional, shown once results appear
//   │                                            │
//   │  [Results list] or [Empty / Loading state] │
//   └──────────────────────────────────────────┘
//
// States:
//   .idle     — hero prompt: "Search your saves"
//   .searching — spinner below search bar
//   .results  — list of SearchResultRow cards
//   .empty    — "No results for "query""
//   .failed   — error message with retry

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            NexusBackground()

            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, NexusSpacing.sideGutter)
                    .padding(.top, NexusSpacing.sm)
                    .padding(.bottom, NexusSpacing.xs)

                Rectangle()
                    .fill(Color.Nexus.hair)
                    .frame(height: NexusBorder.hair)

                stateContent
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                    .font(.Nexus.labelMedium)
                    .foregroundColor(.Nexus.accent)
            }
        }
        .onAppear { searchFocused = true }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: NexusSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.Nexus.faint)

            TextField("Search your saves...", text: $vm.query)
                .font(.Nexus.bodyMedium)
                .foregroundColor(.Nexus.ink)
                .tint(Color.Nexus.accent)
                .focused($searchFocused)
                .submitLabel(.search)
                .onChange(of: vm.query) { _, newValue in
                    vm.onQueryChange(newValue)
                }

            if !vm.query.isEmpty {
                Button {
                    vm.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.Nexus.ghost)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, NexusSpacing.md)
        .frame(height: 40)
        .background(Color.Nexus.surface2)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.xl)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
        )
    }

    // MARK: - State content router

    @ViewBuilder
    private var stateContent: some View {
        switch vm.state {
        case .idle:
            idleState
        case .searching:
            searchingState
        case .results(let items):
            resultsList(items: items)
        case .empty:
            emptyState
        case .failed(let msg):
            failedState(message: msg)
        }
    }

    // MARK: - Idle state

    private var idleState: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "magnifyingglass",
                title: "Search your saves",
                subtitle: "Full-text and semantic search across all your collections."
            )
            Spacer()
        }
    }

    // MARK: - Searching state

    private var searchingState: some View {
        VStack(spacing: NexusSpacing.md) {
            Spacer()
            EchoPulseView()
                .frame(height: 44)
            Text("Searching…")
                .font(.Nexus.caption)
                .foregroundColor(.Nexus.ghost)
                .kerning(NexusKerning.normal)
            Spacer()
        }
    }

    // MARK: - Results list

    private func resultsList(items: [SearchResultItem]) -> some View {
        ScrollView {
            LazyVStack(spacing: NexusSpacing.sm) {
                // Mode indicator header
                if vm.embeddingAvailable {
                    semanticBadge
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(items) { item in
                    SearchResultRow(item: item)
                }
            }
            .padding(.horizontal, NexusSpacing.sideGutter)
            .padding(.top, NexusSpacing.md)
            .padding(.bottom, NexusSpacing.xl)
        }
    }

    // Small badge shown when semantic search contributed to results
    private var semanticBadge: some View {
        HStack(spacing: NexusSpacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .semibold))
            Text("Hybrid · Full-text + semantic")
                .font(.Nexus.overline)
                .kerning(NexusKerning.wide)
        }
        .foregroundColor(.Nexus.accent)
        .padding(.horizontal, NexusSpacing.sm)
        .padding(.vertical, 3)
        .background(Color.Nexus.bloom.opacity(0.5))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.Nexus.accent.opacity(0.2), lineWidth: NexusBorder.hair))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "doc.text.magnifyingglass",
                title: "No results for \"\(vm.query)\"",
                subtitle: "Try different keywords or save more content to your collections."
            )
            Spacer()
        }
    }

    // MARK: - Failed state

    private func failedState(message: String) -> some View {
        VStack {
            Spacer()
            ErrorStateView(message: message) {
                vm.onQueryChange(vm.query)
            }
            Spacer()
        }
    }
}

// MARK: - SearchResultRow
//
// Full-width card for one search result.
// Layout mirrors SourceCard for visual consistency within the same product surface.
//
//   [icon] [title ·············] [score dot]
//          [domain overline]
//          [summary — 2 lines]
//          [tag] [tag]

private struct SearchResultRow: View {
    let item: SearchResultItem
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
            // Content-type icon badge
            Image(systemName: contentTypeIcon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.Nexus.faint)
                .frame(width: 28, height: 28)
                .background(Color.Nexus.surface2)
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xs))

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top) {
                    Text(item.title ?? Item.humanizeURLTitle(item.url))
                        .font(.Nexus.labelMedium)
                        .foregroundColor(.Nexus.ink)
                        .lineLimit(2)
                        .kerning(NexusKerning.normal)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: NexusSpacing.xs)

                    ScoreDot(score: item.score)
                }

                if let domain = item.domain {
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
        if let summary = item.summary {
            Text(summary)
                .font(.Nexus.bodySmall)
                .foregroundColor(.Nexus.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Tags

    @ViewBuilder
    private var tagsSection: some View {
        if !item.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NexusSpacing.xs) {
                    ForEach(item.tags.prefix(5), id: \.self) { tag in
                        SearchTagChip(label: tag)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: Helpers

    private var contentTypeIcon: String {
        switch item.contentType {
        case "podcast":      return "mic"
        case "video":        return "play.rectangle"
        case "youtube":      return "play.rectangle.fill"
        case "thread":       return "bubble.left.and.bubble.right"
        case "blog":         return "text.alignleft"
        case "announcement": return "megaphone"
        default:             return "doc.text"
        }
    }
}

// MARK: - ScoreDot
//
// Small relevance indicator: filled circle whose opacity encodes score.
// Full score (1.0) = accent color at full opacity; low score = ghost at 40%.
// Avoids showing raw numbers which feel "techy" and not user-friendly.

private struct ScoreDot: View {
    let score: Double

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 6, height: 6)
            .padding(.top, 4)  // align with first line of text
    }

    private var dotColor: Color {
        if score >= 0.75 {
            return Color.Nexus.accent
        } else if score >= 0.5 {
            return Color.Nexus.accent.opacity(0.55)
        } else {
            return Color.Nexus.ghost.opacity(0.4)
        }
    }
}

// MARK: - SearchTagChip (matches TagChip in CollectionView)

private struct SearchTagChip: View {
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
