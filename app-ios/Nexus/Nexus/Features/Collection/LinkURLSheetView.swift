import SwiftUI

// MARK: - Detected content type
//
// A lightweight local enum representing the three content families the sheet
// can detect.  Kept separate from Item.ContentType so the sheet has no
// compile-time dependency on the model layer's full enum.

enum DetectedContentType: String, Identifiable, Equatable {
    case youtube
    case pdf
    case website

    // Identifiable conformance — used by .sheet(item:) in ResearchFlowView.
    var id: String { rawValue }

    // Human-readable label shown in the chip.
    var label: String {
        switch self {
        case .youtube: return "YouTube"
        case .pdf:     return "PDF"
        case .website: return "Website"
        }
    }

    // SF Symbol for the chip icon.
    var icon: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .pdf:     return "doc.fill"
        case .website: return "globe"
        }
    }

    // String sent to the backend's contentType field.
    var backendString: String {
        switch self {
        case .youtube: return "youtube"
        case .pdf:     return "pdf"
        case .website: return "article"
        }
    }

    // Chip accent colour — tinted to match ContentTypeIconBadge palette in
    // SourcesTabView for visual consistency across the product.
    var foregroundColor: Color {
        switch self {
        case .youtube: return Color(hex: "#B84C3A") // warm red
        case .pdf:     return Color(hex: "#4A7ABB") // cool blue
        case .website: return Color(hex: "#4A8A5C") // sage green
        }
    }

    var backgroundColor: Color {
        switch self {
        case .youtube: return Color(hex: "#FCF0EE")
        case .pdf:     return Color(hex: "#EEF3FB")
        case .website: return Color(hex: "#F0F7EE")
        }
    }
}

// MARK: - Content-type detection

/// Pure function — no side effects, testable without a view.
/// Rules (applied in order):
///   1. Host contains "youtube.com" or "youtu.be"  → .youtube
///   2. Path ends with ".pdf" (case-insensitive)    → .pdf
///   3. Anything else with a parseable host          → .website
///   4. URL cannot be parsed                         → nil (chip hidden)
func detectContentType(from rawURL: String) -> DetectedContentType? {
    // Prepend scheme if missing so URL(string:) parses correctly.
    var candidate = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
    if !candidate.isEmpty,
       !candidate.lowercased().hasPrefix("http://"),
       !candidate.lowercased().hasPrefix("https://") {
        candidate = "https://" + candidate
    }
    guard let url = URL(string: candidate), url.host != nil else { return nil }

    let host = (url.host ?? "").lowercased()
    let path = url.path.lowercased()

    if host.contains("youtube.com") || host.contains("youtu.be") {
        return .youtube
    }
    if path.hasSuffix(".pdf") {
        return .pdf
    }
    return .website
}

// MARK: - LinkURLSheetView

/// Sheet for adding a source by pasting a URL.
///
/// Presented from FRELinkButtons when the user taps "Website", "PDF", or
/// "YouTube".  Pre-populates the content-type chip based on the tapped button,
/// then re-detects on every keystroke as the URL field is edited.
///
/// Caller is responsible for:
///   • Presenting this view (typically via .sheet or .fullScreenCover)
///   • Passing the collection to ingest into (collectionId)
///   • Reacting to onComplete to refresh the source list
///
/// Parameters
///   initialContentType  — pre-hint from the tapped button; overridden by detection
///   collectionId        — nil when called from the FRE (no collection yet)
///   collections         — available collections for the picker; empty → hide picker
///   onComplete          — called with the ingest job ID on success

struct LinkURLSheetView: View {
    // ── Inputs ──────────────────────────────────────────────────────────────
    let initialContentType: DetectedContentType
    let collections: [NexusCollection]
    /// When non-nil the picker is skipped and this collection is used directly.
    var preselectedCollectionId: UUID? = nil
    let onComplete: (_ jobId: String, _ collectionId: UUID) -> Void

    // ── Local state ──────────────────────────────────────────────────────────
    @State private var urlText: String = ""
    @State private var detectedType: DetectedContentType?
    @State private var selectedCollectionId: UUID?
    @State private var isSubmitting = false
    @State private var submitError: String?

    @FocusState private var urlFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // Resolved content type: detection result → initial hint → .website
    private var resolvedType: DetectedContentType {
        detectedType ?? initialContentType
    }

    private var canSubmit: Bool {
        guard !isSubmitting else { return false }
        guard detectedType != nil else { return false }     // URL must be parseable
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard effectiveCollectionId != nil else { return false }
        return true
    }

    private var effectiveCollectionId: UUID? {
        preselectedCollectionId ?? selectedCollectionId
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header (native drag indicator sits above) ──────────────────
            sheetHeader
                .padding(.horizontal, NexusSpacing.standard)
                .padding(.top, NexusSpacing.md)
                .padding(.bottom, NexusSpacing.sm)

            Divider()
                .background(Color.Nexus.hair)

            ScrollView {
                VStack(alignment: .leading, spacing: NexusSpacing.lg) {
                    // ── URL field ──────────────────────────────────────────
                    urlField

                    // ── Content-type chip (auto-updates) ──────────────────
                    contentTypeRow

                    // ── Collection picker (when collectionId not pre-set) ──
                    if preselectedCollectionId == nil && !collections.isEmpty {
                        collectionPicker
                    }

                    // ── Error banner ───────────────────────────────────────
                    if let error = submitError {
                        ErrorInlineBanner(message: error)
                    }
                }
                .padding(.horizontal, NexusSpacing.standard)
                .padding(.top, NexusSpacing.lg)
                .padding(.bottom, NexusSpacing.xxl)
            }

            Spacer(minLength: 0)

            // ── CTA bar ────────────────────────────────────────────────────
            ctaBar
                .padding(.horizontal, NexusSpacing.standard)
                .padding(.bottom, NexusSpacing.xxl)
                .padding(.top, NexusSpacing.sm)
                .background(
                    LinearGradient(
                        colors: [Color.Nexus.pageEnd.opacity(0), Color.Nexus.pageEnd],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.3)
                    )
                )
        }
        .background(NexusBackground())
        .onAppear {
            selectedCollectionId = preselectedCollectionId ?? collections.first?.id
            // Delay so the sheet animation completes before keyboard appears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                urlFocused = true
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        // Grabber is the native drag indicator now (.presentationDragIndicator).
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Add a source")
                    .font(.Nexus.headingSmall)
                    .foregroundColor(.Nexus.ink)
                    .kerning(NexusKerning.tighter)
                Text("Paste a link to save it to your collection")
                    .font(.Nexus.caption)
                    .foregroundColor(.Nexus.ghost)
                    .kerning(NexusKerning.normal)
            }

            Spacer()

            // Close button
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.Nexus.surface2)
                        .frame(width: 30, height: 30)
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.Nexus.muted)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - URL field

    private var urlField: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.xs) {
            Text("URL")
                .font(.Nexus.overline)
                .foregroundColor(.Nexus.ghost)
                .kerning(NexusKerning.wide)
                .textCase(.uppercase)

            ZStack(alignment: .leading) {
                if urlText.isEmpty {
                    Text("https://")
                        .font(.Nexus.bodySmall)
                        .foregroundColor(.Nexus.ghost)
                        .padding(.horizontal, NexusSpacing.md)
                        .allowsHitTesting(false)
                }

                TextField("", text: $urlText)
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.ink)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($urlFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if canSubmit { Task { await submit() } }
                    }
                    .padding(.horizontal, NexusSpacing.md)
                    .padding(.vertical, NexusSpacing.sm + 4)
                    // Live detection — runs on every keystroke
                    .onChange(of: urlText) { _, newValue in
                        withAnimation(NexusAnimation.element) {
                            detectedType = detectContentType(from: newValue)
                        }
                        submitError = nil
                    }
            }
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.base)
                    .stroke(
                        urlFocused ? Color.Nexus.accent.opacity(0.6) : Color.Nexus.border,
                        lineWidth: urlFocused ? NexusBorder.base : NexusBorder.hair
                    )
            )
            .animation(NexusAnimation.element, value: urlFocused)
        }
    }

    // MARK: - Content-type chip row

    @ViewBuilder
    private var contentTypeRow: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.xs) {
            Text("Detected as")
                .font(.Nexus.overline)
                .foregroundColor(.Nexus.ghost)
                .kerning(NexusKerning.wide)
                .textCase(.uppercase)

            if detectedType != nil {
                ContentTypeChip(type: resolvedType)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else {
                // Placeholder when no parseable URL typed yet
                Text("–")
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.ghost)
                    .padding(.vertical, NexusSpacing.xs)
                    .transition(.opacity)
            }
        }
        .animation(NexusAnimation.element, value: detectedType)
    }

    // MARK: - Collection picker

    @ViewBuilder
    private var collectionPicker: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.xs) {
            Text("Save to collection")
                .font(.Nexus.overline)
                .foregroundColor(.Nexus.ghost)
                .kerning(NexusKerning.wide)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NexusSpacing.sm) {
                    ForEach(collections) { collection in
                        CollectionChip(
                            name: collection.name,
                            isSelected: selectedCollectionId == collection.id
                        ) {
                            withAnimation(NexusAnimation.element) {
                                selectedCollectionId = collection.id
                            }
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - CTA bar

    private var ctaBar: some View {
        Button(action: { Task { await submit() } }) {
            ZStack {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.85)
                } else {
                    HStack(spacing: NexusSpacing.sm) {
                        Image(systemName: resolvedType.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text("Save \(resolvedType.label)")
                            .font(.system(size: 16, weight: .semibold))
                            .kerning(NexusKerning.snug)
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: NexusSpacing.buttonHeight)
            .background(canSubmit ? Color.Nexus.accent : Color.Nexus.ghost)
            .clipShape(Capsule())
            .animation(NexusAnimation.element, value: canSubmit)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }

    // MARK: - Submit

    private func submit() async {
        guard canSubmit, let collId = effectiveCollectionId else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        var candidate = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !candidate.lowercased().hasPrefix("http://"),
           !candidate.lowercased().hasPrefix("https://") {
            candidate = "https://" + candidate
        }

        do {
            let response = try await APIClient.shared.ingest(
                url: candidate,
                collectionId: collId,
                contentType: resolvedType.backendString
            )
            dismiss()
            onComplete(response.jobId, collId)
        } catch let e as APIError {
            submitError = e.errorDescription ?? "Something went wrong. Please try again."
        } catch {
            submitError = error.localizedDescription
        }
    }
}

// MARK: - Content-type chip

/// Read-only pill showing the auto-detected content type.
/// Colour-coded to match ContentTypeIconBadge in SourcesTabView.

private struct ContentTypeChip: View {
    let type: DetectedContentType

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: type.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(type.foregroundColor)

            Text(type.label)
                .font(.Nexus.labelSmall)
                .foregroundColor(type.foregroundColor)
                .kerning(NexusKerning.normal)
        }
        .padding(.horizontal, NexusSpacing.md)
        .padding(.vertical, NexusSpacing.xs + 2)
        .background(type.backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(type.foregroundColor.opacity(0.25), lineWidth: NexusBorder.hair)
        )
    }
}

// MARK: - Collection chip (picker row)

private struct CollectionChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isSelected ? .Nexus.accent : .Nexus.muted)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(name)
                    .font(.Nexus.labelSmall)
                    .foregroundColor(isSelected ? .Nexus.accent : .Nexus.muted)
                    .kerning(NexusKerning.normal)
                    .lineLimit(1)
            }
            .padding(.horizontal, NexusSpacing.md)
            .padding(.vertical, NexusSpacing.xs + 2)
            .background(isSelected ? Color.Nexus.bloom.opacity(0.4) : Color.Nexus.surface2)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.Nexus.accent.opacity(0.3) : Color.Nexus.border,
                        lineWidth: NexusBorder.hair
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? NexusScale.pressLight : 1)
        .animation(NexusAnimation.press, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { p in isPressed = p }, perform: {})
    }
}

// MARK: - Inline error banner

private struct ErrorInlineBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: NexusSpacing.sm) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.Nexus.destructive)
            Text(message)
                .font(.Nexus.bodySmall)
                .foregroundColor(.Nexus.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(NexusSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Nexus.destructive.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.base)
                .stroke(Color.Nexus.destructive.opacity(0.18), lineWidth: NexusBorder.hair)
        )
    }
}
