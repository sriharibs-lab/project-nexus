import SwiftUI

// MARK: - Item Detail / Reader View
//
// Full-screen reader for one saved source.
//
// Layout (top → bottom, inside ScrollView):
//   ─ Type icon + domain overline
//   ─ Title (headingMedium)
//   ─ Summary hero block (body text on surface2 card)
//   ─ Key insights block (numbered bullets, only when completed + insights exist)
//   ─ Tags row (horizontal scroll)
//   ─ Divider
//   ─ Full-text body (raw extracted content, scrolls with page)
//   ─ "Open original" footer link
//
// Data strategy:
//   • Card tap passes the lightweight `Item` from the list (has title/summary/insights/tags).
//   • On appear, `ItemDetailViewModel` fetches the full item (GET /items/{id}) which
//     includes `raw_content`. Until that completes, the view shows the hero+insights from
//     the list-level item; the full-text section shows a loading placeholder.
//
// Design rules (DESIGN_LANGUAGE.md):
//   • Inline cards use solid fill + hairline border. No glass.
//   • Press bounce on every tappable.
//   • Accent (#7054AB) used sparingly — only the "Open original" CTA.

struct ItemDetailView: View {
    let item: Item
    let collectionId: UUID

    @StateObject private var vm: ItemDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(item: Item, collectionId: UUID) {
        self.item = item
        self.collectionId = collectionId
        _vm = StateObject(wrappedValue: ItemDetailViewModel(item: item, collectionId: collectionId))
    }

    var body: some View {
        ZStack {
            Color.Nexus.pageBackground.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // ── Metadata header ──────────────────────────────────────
                    metadataHeader
                        .padding(.horizontal, NexusSpacing.sideGutter)
                        .padding(.top, NexusSpacing.lg)

                    // ── Title ────────────────────────────────────────────────
                    titleSection
                        .padding(.horizontal, NexusSpacing.sideGutter)
                        .padding(.top, NexusSpacing.sm)

                    // ── Summary hero ─────────────────────────────────────────
                    summaryHero
                        .padding(.horizontal, NexusSpacing.sideGutter)
                        .padding(.top, NexusSpacing.lg)

                    // ── Key insights ─────────────────────────────────────────
                    insightsBlock
                        .padding(.horizontal, NexusSpacing.sideGutter)
                        .padding(.top, NexusSpacing.lg)

                    // ── Tags row ─────────────────────────────────────────────
                    tagsRow
                        .padding(.top, NexusSpacing.md)
                        .padding(.bottom, NexusSpacing.lg)

                    // ── Divider ──────────────────────────────────────────────
                    Rectangle()
                        .fill(Color.Nexus.hair)
                        .frame(height: NexusBorder.hair)
                        .padding(.horizontal, NexusSpacing.sideGutter)

                    // ── Full text body ───────────────────────────────────────
                    fullTextSection
                        .padding(.horizontal, NexusSpacing.sideGutter)
                        .padding(.top, NexusSpacing.lg)
                        .padding(.bottom, NexusSpacing.xl)

                    // ── Open original ────────────────────────────────────────
                    openOriginalFooter
                        .padding(.horizontal, NexusSpacing.sideGutter)
                        .padding(.bottom, NexusSpacing.xxxl + NexusSpacing.safeBottom)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                openInSafariButton
            }
        }
        .task { await vm.fetchFullContent() }
    }

    // MARK: - Metadata header (icon + domain + read time)

    private var metadataHeader: some View {
        HStack(spacing: NexusSpacing.sm) {
            // Content type badge
            Image(systemName: vm.displayItem.contentType.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.Nexus.faint)
                .frame(width: 24, height: 24)
                .background(Color.Nexus.surface2)
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.xs))

            // Domain overline
            if let domain = extractDomain(from: vm.displayItem.url) {
                Text(domain)
                    .font(.Nexus.overline)
                    .foregroundColor(.Nexus.ghost)
                    .kerning(NexusKerning.wide)
                    .textCase(.uppercase)
            }

            Spacer()

            // Estimated read time (only when full text available)
            if let wordCount = vm.wordCount {
                let minutes = max(1, wordCount / 200)
                Text("\(minutes) min read")
                    .font(.Nexus.overline)
                    .foregroundColor(.Nexus.ghost)
                    .kerning(NexusKerning.wide)
            }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        Text(vm.displayItem.title ?? vm.displayItem.url)
            .font(.Nexus.headingMedium)
            .foregroundColor(.Nexus.ink)
            .kerning(NexusKerning.tighter)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Summary hero

    @ViewBuilder
    private var summaryHero: some View {
        if vm.displayItem.ingestStatus == .completed, let summary = vm.displayItem.summary {
            VStack(alignment: .leading, spacing: NexusSpacing.xs) {
                Label("Summary", systemImage: "sparkles")
                    .font(.Nexus.labelSmall)
                    .foregroundColor(.Nexus.accent)
                    .kerning(NexusKerning.wide)
                    .textCase(.uppercase)
                    .labelStyle(IconLeadingLabelStyle())

                Text(summary)
                    .font(.Nexus.bodyMedium)
                    .foregroundColor(.Nexus.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
            }
            .padding(NexusSpacing.standard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Nexus.surface2)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.base)
                    .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
            )
        } else if vm.displayItem.ingestStatus == .processing {
            processingPlaceholder(label: "Generating summary…")
        }
    }

    // MARK: - Key insights block

    @ViewBuilder
    private var insightsBlock: some View {
        if vm.displayItem.ingestStatus == .completed,
           let insights = vm.displayItem.insights, !insights.isEmpty {
            VStack(alignment: .leading, spacing: NexusSpacing.md) {
                Label("Key Insights", systemImage: "lightbulb")
                    .font(.Nexus.labelSmall)
                    .foregroundColor(.Nexus.faint)
                    .kerning(NexusKerning.wide)
                    .textCase(.uppercase)
                    .labelStyle(IconLeadingLabelStyle())

                VStack(alignment: .leading, spacing: NexusSpacing.sm) {
                    ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                        HStack(alignment: .top, spacing: NexusSpacing.sm) {
                            // Numbered bullet
                            Text("\(index + 1)")
                                .font(.Nexus.labelSmall)
                                .foregroundColor(.Nexus.accent)
                                .frame(width: 18, alignment: .trailing)
                                .padding(.top, 2)

                            Text(insight)
                                .font(.Nexus.bodySmall)
                                .foregroundColor(.Nexus.muted)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(NexusSpacing.standard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.base)
                    .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
            )
        }
    }

    // MARK: - Tags row

    @ViewBuilder
    private var tagsRow: some View {
        if !vm.displayItem.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NexusSpacing.xs) {
                    ForEach(vm.displayItem.tags, id: \.self) { tag in
                        TagChip(label: tag)
                    }
                }
                .padding(.horizontal, NexusSpacing.sideGutter)
            }
        }
    }

    // MARK: - Full text section

    @ViewBuilder
    private var fullTextSection: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.md) {
            Text("Full Text")
                .font(.Nexus.labelSmall)
                .foregroundColor(.Nexus.faint)
                .kerning(NexusKerning.wide)
                .textCase(.uppercase)

            if vm.isLoadingFullContent {
                processingPlaceholder(label: "Loading full text…")
            } else if let rawContent = vm.fullContent {
                Text(rawContent)
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(5)
                    .kerning(NexusKerning.wide)
            } else {
                // Full text not available — show inline notice
                HStack(spacing: NexusSpacing.sm) {
                    Image(systemName: "text.page.slash")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.Nexus.ghost)
                    Text("Full text not yet extracted. Open the original source to read.")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.ghost)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(NexusSpacing.standard)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.Nexus.surface2)
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
            }
        }
    }

    // MARK: - Open original footer

    private var openOriginalFooter: some View {
        OpenOriginalButton(urlString: vm.displayItem.url)
    }

    // MARK: - Safari toolbar button

    private var openInSafariButton: some View {
        OpenInSafariButton(urlString: vm.displayItem.url)
    }

    // MARK: - Processing placeholder

    private func processingPlaceholder(label: String) -> some View {
        HStack(spacing: NexusSpacing.xs) {
            Circle()
                .fill(Color.Nexus.accent.opacity(0.6))
                .frame(width: 5, height: 5)
            Text(label)
                .font(.Nexus.caption)
                .foregroundColor(.Nexus.ghost)
        }
        .padding(.vertical, NexusSpacing.sm)
    }

    // MARK: - Helpers

    private func extractDomain(from urlString: String) -> String? {
        guard let host = URL(string: urlString)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

// MARK: - Open Original Button

private struct OpenOriginalButton: View {
    let urlString: String
    @State private var isPressed = false

    var body: some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(spacing: NexusSpacing.sm) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .medium))
                    Text("Open original source")
                        .font(.Nexus.labelMedium)
                        .kerning(NexusKerning.normal)
                }
                .foregroundColor(.Nexus.accent)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: NexusSpacing.buttonHeight)
                .background(Color.Nexus.bloom.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: NexusRadius.md)
                        .stroke(Color.Nexus.accent.opacity(0.2), lineWidth: NexusBorder.hair)
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(isPressed ? NexusScale.pressLight : 1)
            .animation(NexusAnimation.press, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
        }
    }
}

// MARK: - Open in Safari toolbar button

private struct OpenInSafariButton: View {
    let urlString: String

    var body: some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                Image(systemName: "safari")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.Nexus.accent)
                    .frame(width: NexusSpacing.hitTarget, height: NexusSpacing.hitTarget)
            }
        }
    }
}

// MARK: - Icon-leading label style (icon + title, no background)

private struct IconLeadingLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
    }
}

// MARK: - View Model

@MainActor
final class ItemDetailViewModel: ObservableObject {
    /// The item shown immediately (from the Sources list — has title/summary/insights/tags).
    /// Replaced by the full fetch once it completes.
    @Published private(set) var displayItem: Item
    @Published private(set) var isLoadingFullContent = false
    @Published private(set) var fullContent: String?
    @Published private(set) var error: APIError?

    var wordCount: Int? {
        guard let text = fullContent else { return nil }
        return text.split(separator: " ").count
    }

    private let collectionId: UUID

    init(item: Item, collectionId: UUID) {
        self.displayItem = item
        self.collectionId = collectionId
        // Populate fullContent immediately if it was already on the item (e.g. coming
        // from a future list endpoint that includes raw_content).
        self.fullContent = item.rawContent
    }

    func fetchFullContent() async {
        // Only fetch if we don't already have raw content and ingest is done
        guard fullContent == nil, displayItem.ingestStatus == .completed else { return }
        isLoadingFullContent = true
        defer { isLoadingFullContent = false }
        do {
            let fullItem = try await APIClient.shared.fetchItem(id: displayItem.id, in: collectionId)
            displayItem = fullItem
            fullContent = fullItem.rawContent
        } catch let e as APIError {
            error = e
            // Non-fatal: reader still shows summary + insights from the initial item
        } catch {
            // Non-fatal: same as above
        }
    }
}
