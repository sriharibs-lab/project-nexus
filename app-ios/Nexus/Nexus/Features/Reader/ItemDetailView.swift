import Combine
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
//   ─ Full-text body (HighlightableTextView — UITextView UIViewRepresentable)
//   ─ "Open original" footer link
//
// Data strategy:
//   • Card tap passes the lightweight `Item` from the list (has title/summary/insights/tags).
//   • On appear, `ItemDetailViewModel` fetches the full item (GET /items/{id}) which
//     includes `raw_content`. Until that completes, the view shows the hero+insights from
//     the list-level item; the full-text section shows a loading placeholder.
//
// Highlight strategy (1D-004):
//   • Full-text area uses HighlightableTextView (UIViewRepresentable / UITextView).
//   • User selects text → floating HighlightToolbar appears with 3 color swatches.
//   • Tapping a color swatch → saves Annotation to AnnotationStore → UITextView re-renders.
//   • Tapping an existing highlight → HighlightDetailSheet appears with "Remove" option.
//   • All storage is local-only (AnnotationStore / FileManager JSON).
//
// Design rules (DESIGN_LANGUAGE.md):
//   • Inline cards use solid fill + hairline border. No glass.
//   • Press bounce on every tappable.
//   • Accent (#7054AB) used sparingly — only the "Open original" CTA.

struct ItemDetailView: View {
    let item: Item
    let collectionId: UUID

    @StateObject private var vm: ItemDetailViewModel
    /// ObservedObject so the view re-renders when annotations are mutated.
    @ObservedObject private var annotationStore = AnnotationStore.shared
    @Environment(\.dismiss) private var dismiss

    // MARK: Highlight state

    /// Text the user has just selected — drives the floating toolbar.
    @State private var selectedTextInfo: SelectedTextInfo?
    /// Annotation the user tapped — drives the "Remove" sheet.
    @State private var tappedAnnotation: Annotation?
    /// Controls presentation of the remove-highlight confirmation sheet.
    @State private var showRemoveSheet = false

    init(item: Item, collectionId: UUID) {
        self.item = item
        self.collectionId = collectionId
        _vm = StateObject(wrappedValue: ItemDetailViewModel(item: item, collectionId: collectionId))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            NexusBackground()

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
            // Dismiss the toolbar when user taps outside the text area
            .onTapGesture {
                if selectedTextInfo != nil {
                    withAnimation(NexusAnimation.element) { selectedTextInfo = nil }
                }
            }

            // ── Floating highlight toolbar ───────────────────────────────
            if let info = selectedTextInfo {
                HighlightToolbar(
                    selectedInfo: info,
                    itemId: item.id,
                    onHighlight: { annotation in
                        annotationStore.add(annotation)
                        withAnimation(NexusAnimation.element) { selectedTextInfo = nil }
                    },
                    onDismiss: {
                        withAnimation(NexusAnimation.element) { selectedTextInfo = nil }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, NexusSpacing.sideGutter)
                .padding(.bottom, NexusSpacing.safeBottom + NexusSpacing.sm)
                .zIndex(10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                openInSafariButton
            }
        }
        .task { await vm.fetchFullContent() }
        // ── Remove highlight sheet ─────────────────────────────────────
        .sheet(isPresented: $showRemoveSheet) {
            if let annotation = tappedAnnotation {
                RemoveHighlightSheet(annotation: annotation) {
                    annotationStore.remove(id: annotation.id, for: annotation.itemId)
                    showRemoveSheet = false
                    tappedAnnotation = nil
                }
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
            }
        }
        .animation(NexusAnimation.element, value: selectedTextInfo != nil)
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

    // MARK: - Full text section (with highlight support)

    @ViewBuilder
    private var fullTextSection: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.md) {
            // Header row: "Full Text" label + highlight count badge + optional offline badge
            HStack(spacing: NexusSpacing.sm) {
                Text("Full Text")
                    .font(.Nexus.labelSmall)
                    .foregroundColor(.Nexus.faint)
                    .kerning(NexusKerning.wide)
                    .textCase(.uppercase)

                // Highlight count badge — shown when there are active highlights
                let annotations = annotationStore.annotations(for: item.id)
                if !annotations.isEmpty {
                    Text("\(annotations.count)")
                        .font(.Nexus.overline)
                        .foregroundColor(.Nexus.accent)
                        .padding(.horizontal, NexusSpacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.Nexus.bloom.opacity(0.5))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.Nexus.accent.opacity(0.2), lineWidth: NexusBorder.hair)
                        )
                }

                if vm.isFromCache {
                    offlineBadge
                }
            }

            if vm.isLoadingFullContent {
                processingPlaceholder(label: "Loading full text…")
            } else if let rawContent = vm.fullContent {
                // HighlightableTextView — UITextView wrapper for highlight support
                // UIFont/UIColor construction is isolated inside HighlightableTextView;
                // only SwiftUI-native types are passed here (preserves UIKit boundary).
                HighlightableTextView(
                    text: rawContent,
                    annotations: annotationStore.annotations(for: item.id),
                    font: .body,
                    textColor: Color.Nexus.muted,
                    onSelectText: { info in
                        withAnimation(NexusAnimation.element) {
                            selectedTextInfo = info
                        }
                    },
                    onTapHighlight: { annotation in
                        tappedAnnotation = annotation
                        showRemoveSheet = true
                    }
                )
                // intrinsicContentSize drives the frame — UITextView needs an explicit
                // width to compute its intrinsic height. GeometryReader provides it.
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Offline badge (shown when content served from local cache)

    private var offlineBadge: some View {
        Label("Offline", systemImage: "wifi.slash")
            .font(.Nexus.caption)
            .foregroundColor(.Nexus.ghost)
            .labelStyle(IconLeadingLabelStyle())
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

// MARK: - Highlight Toolbar
//
// Floating card shown at the bottom of the screen when the user has selected text.
// Three color swatches (plum, amber, sage) + dismiss.
// Matches DESIGN_LANGUAGE §1 (inline surface: solid fill + hairline border).

private struct HighlightToolbar: View {
    let selectedInfo: SelectedTextInfo
    let itemId: UUID
    let onHighlight: (Annotation) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: NexusSpacing.md) {
            // Preview snippet (up to 40 chars)
            Text(previewText)
                .font(.Nexus.caption)
                .foregroundColor(.Nexus.muted)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Color swatches
            HStack(spacing: NexusSpacing.sm) {
                ForEach(HighlightColor.allCases, id: \.self) { color in
                    ColorSwatch(color: color) {
                        let annotation = Annotation(
                            itemId: itemId,
                            highlightedText: selectedInfo.text,
                            startOffset: selectedInfo.startOffset,
                            endOffset: selectedInfo.endOffset,
                            color: color
                        )
                        onHighlight(annotation)
                    }
                }
            }

            // Dismiss
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.Nexus.ghost)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, NexusSpacing.standard)
        .padding(.vertical, NexusSpacing.md)
        .background(Color.Nexus.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.base)
                .stroke(Color.Nexus.border, lineWidth: NexusBorder.hair)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private var previewText: String {
        let truncated = selectedInfo.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(40)
        return truncated.count < selectedInfo.text.count ? "\(truncated)…" : String(truncated)
    }
}

// MARK: - Color Swatch

private struct ColorSwatch: View {
    let color: HighlightColor
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.swiftUIColor)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(color.swiftUISolidColor.opacity(0.4), lineWidth: NexusBorder.base)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? NexusScale.pressLight : 1)
        .animation(NexusAnimation.press, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { p in isPressed = p }, perform: {})
        .accessibilityLabel("\(color.displayName) highlight")
    }
}

// MARK: - Remove Highlight Sheet
//
// Presented when the user taps an existing highlighted range.
// Shows a text snippet, the color swatch, and a destructive Remove button.

private struct RemoveHighlightSheet: View {
    let annotation: Annotation
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: NexusSpacing.lg) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.Nexus.ghost.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, NexusSpacing.sm)

            // Highlighted text snippet
            Text("\"\(snippet)\"")
                .font(.Nexus.bodySmall)
                .foregroundColor(.Nexus.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, NexusSpacing.xl)
                .padding(.vertical, NexusSpacing.sm)
                .background(annotation.color.swiftUIColor)
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.sm))

            // Remove button
            Button(role: .destructive, action: onRemove) {
                HStack(spacing: NexusSpacing.sm) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 14, weight: .medium))
                    Text("Remove highlight")
                        .font(.Nexus.labelMedium)
                        .kerning(NexusKerning.normal)
                }
                .foregroundColor(Color.Nexus.destructive)
                .frame(maxWidth: .infinity)
                .frame(height: NexusSpacing.buttonHeight)
                .background(Color.Nexus.destructive.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: NexusRadius.md)
                        .stroke(Color.Nexus.destructive.opacity(0.18), lineWidth: NexusBorder.hair)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, NexusSpacing.sideGutter)

            Spacer()
        }
        .background(Color.Nexus.pageBackground)
    }

    private var snippet: String {
        let trimmed = annotation.highlightedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = trimmed.prefix(60)
        return prefix.count < trimmed.count ? "\(prefix)…" : String(prefix)
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
    /// True when content is being served from the on-disk offline cache (no live network hit).
    @Published private(set) var isFromCache = false

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
        // If the item object already carries raw_content (e.g. passed from a richer list
        // endpoint in the future), cache it and return immediately.
        if let existing = displayItem.rawContent {
            fullContent = existing
            await OfflineContentCache.shared.store(rawContent: existing, for: displayItem.id)
            return
        }

        // 1. Check offline cache before hitting the network.
        if let cached = await OfflineContentCache.shared.rawContent(for: displayItem.id) {
            fullContent = cached
            isFromCache = true
            return
        }

        // 2. Cache miss — fetch from API (only makes sense when ingest is done).
        guard displayItem.ingestStatus == .completed else { return }
        isLoadingFullContent = true
        defer { isLoadingFullContent = false }
        do {
            let fullItem = try await APIClient.shared.fetchItem(id: displayItem.id, in: collectionId)
            displayItem = fullItem
            if let text = fullItem.rawContent {
                fullContent = text
                isFromCache = false
                // Persist so subsequent opens work offline.
                await OfflineContentCache.shared.store(rawContent: text, for: displayItem.id)
            }
        } catch let e as APIError {
            error = e
            // Non-fatal: reader still shows summary + insights from the initial item.
            // If there is cached content from a previous visit, it was already surfaced
            // in step 1, so the user is not left with a blank screen.
        } catch {
            // Non-fatal: same as above
        }
    }
}
