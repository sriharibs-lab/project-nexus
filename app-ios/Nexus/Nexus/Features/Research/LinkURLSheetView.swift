import Combine
import SwiftUI

// MARK: - Content type

enum LinkContentType: String, CaseIterable, Identifiable {
    case website = "Website"
    case pdf     = "PDF"
    case youtube = "YouTube"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .website: return "globe"
        case .pdf:     return "doc"
        case .youtube: return "play.rectangle"
        }
    }

    var apiValue: String {
        switch self {
        case .website: return "article"
        case .pdf:     return "pdf"
        case .youtube: return "video"
        }
    }
}

// MARK: - Sheet view

/// URL paste sheet opened by the + button or link-type buttons in the FRE composer.
/// Detent: .medium initially, expands to .large when the keyboard appears.
///
/// Flow:
///  1. User pastes / types a URL
///  2. Collection name auto-fills from domain (editable)
///  3. Taps "Save to collection"
///  4. POST /v1/collections → creates the collection
///  5. POST /v1/ingest   → queues the URL (fire-and-forget)
///  6. Sheet dismisses and `onComplete(collectionId)` navigates to the new CollectionView
struct LinkURLSheetView: View {
    /// Pre-selected content type (set by which button opened the sheet).
    let initialContentType: LinkContentType
    /// Called with the new collection UUID on successful create+ingest.
    let onComplete: (UUID) -> Void

    @StateObject private var vm: LinkURLViewModel
    @Environment(\.dismiss) private var dismiss

    init(initialContentType: LinkContentType = .website, onComplete: @escaping (UUID) -> Void) {
        self.initialContentType = initialContentType
        self.onComplete = onComplete
        _vm = StateObject(wrappedValue: LinkURLViewModel(contentType: initialContentType))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NexusBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: NexusSpacing.lg) {

                        // ── Content type chips ──
                        contentTypeSelector

                        // ── URL field ──
                        urlField

                        // ── Collection name field ──
                        collectionNameField

                        // ── Error banner ──
                        if let errMsg = vm.errorMessage {
                            errorBanner(message: errMsg) {
                                Task { await vm.submit(dismiss: { dismiss() }, onComplete: onComplete) }
                            }
                        }
                    }
                    .padding(.horizontal, NexusSpacing.standard)
                    .padding(.top, NexusSpacing.lg)
                    .padding(.bottom, NexusSpacing.xxl)
                }
            }
            .navigationTitle("Start with a link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.Nexus.bodyMedium)
                        .foregroundColor(.Nexus.muted)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    saveButton
                }
            }
        }
        .onAppear { vm.autoFillFromClipboard() }
    }

    // MARK: - Content type selector

    private var contentTypeSelector: some View {
        HStack(spacing: NexusSpacing.sm) {
            ForEach(LinkContentType.allCases) { type in
                ContentTypeChip(
                    type: type,
                    isSelected: vm.contentType == type
                ) {
                    withAnimation(NexusAnimation.element) {
                        vm.contentType = type
                    }
                }
            }
        }
    }

    // MARK: - URL field

    private var urlField: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.sm) {
            Text("URL")
                .font(.Nexus.overline)
                .foregroundColor(.Nexus.ghost)
                .kerning(NexusKerning.wide)

            HStack(spacing: NexusSpacing.sm) {
                TextField("https://", text: $vm.urlText)
                    .font(.Nexus.bodyMedium)
                    .foregroundColor(.Nexus.ink)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: vm.urlText) { _, _ in vm.onURLChanged() }

                // Clear button (shown when URL has text)
                if !vm.urlText.isEmpty {
                    Button {
                        vm.urlText = ""
                        vm.collectionName = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.Nexus.ghost)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

                // Paste button (shown when URL is empty and clipboard has URL)
                if vm.urlText.isEmpty {
                    Button {
                        vm.pasteFromClipboard()
                    } label: {
                        Text("Paste")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.Nexus.accent)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(NexusAnimation.element, value: vm.urlText.isEmpty)
            .padding(.horizontal, NexusSpacing.standard)
            .padding(.vertical, NexusSpacing.md)
            .background(Color.Nexus.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous)
                    .stroke(
                        vm.urlValidationError != nil
                            ? Color.Nexus.destructive.opacity(0.5)
                            : Color.Nexus.border,
                        lineWidth: NexusBorder.base
                    )
            )

            if let valErr = vm.urlValidationError {
                Text(valErr)
                    .font(.Nexus.caption)
                    .foregroundColor(.Nexus.destructive)
                    .transition(.opacity)
            }
        }
        .animation(NexusAnimation.element, value: vm.urlValidationError != nil)
    }

    // MARK: - Collection name field

    private var collectionNameField: some View {
        VStack(alignment: .leading, spacing: NexusSpacing.sm) {
            Text("COLLECTION NAME")
                .font(.Nexus.overline)
                .foregroundColor(.Nexus.ghost)
                .kerning(NexusKerning.wide)

            TextField(vm.collectionNamePlaceholder, text: $vm.collectionName)
                .font(.Nexus.bodyMedium)
                .foregroundColor(.Nexus.ink)
                .autocorrectionDisabled()
                .padding(.horizontal, NexusSpacing.standard)
                .padding(.vertical, NexusSpacing.md)
                .background(Color.Nexus.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: NexusRadius.md, style: .continuous)
                        .stroke(Color.Nexus.border, lineWidth: NexusBorder.base)
                )
        }
    }

    // MARK: - Save button

    private var saveButton: some View {
        Button {
            Task {
                await vm.submit(dismiss: { dismiss() }, onComplete: onComplete)
            }
        } label: {
            ZStack {
                if vm.isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.75)
                        .frame(width: 72, height: 30)
                        .background(Color.Nexus.accent)
                        .clipShape(Capsule())
                } else {
                    Text("Save")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 30)
                        .background(vm.canSubmit ? Color.Nexus.accent : Color.Nexus.ghost)
                        .clipShape(Capsule())
                }
            }
            .animation(NexusAnimation.element, value: vm.isSubmitting)
        }
        .disabled(!vm.canSubmit || vm.isSubmitting)
    }

    // MARK: - Error banner

    @ViewBuilder
    private func errorBanner(message: String, onRetry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: NexusSpacing.sm) {
            HStack(spacing: NexusSpacing.sm) {
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.Nexus.destructive)
                Text(message)
                    .font(.Nexus.bodySmall)
                    .foregroundColor(.Nexus.destructive)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            Button("Retry", action: onRetry)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.Nexus.accent)
        }
        .padding(NexusSpacing.md)
        .background(Color.Nexus.destructive.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.base))
        .overlay(
            RoundedRectangle(cornerRadius: NexusRadius.base)
                .stroke(Color.Nexus.destructive.opacity(0.15), lineWidth: NexusBorder.hair)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Content type chip

private struct ContentTypeChip: View {
    let type: LinkContentType
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 13, weight: .medium))
                Text(type.rawValue)
                    .font(.system(size: 13.5, weight: .medium))
                    .kerning(-0.1)
            }
            .foregroundColor(isSelected ? .Nexus.accent : .Nexus.muted)
            .padding(.horizontal, NexusSpacing.md)
            .frame(height: 36)
            .background(isSelected ? Color.Nexus.bloom.opacity(0.55) : Color.Nexus.cardBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.Nexus.accent.opacity(0.3) : Color.Nexus.border,
                        lineWidth: isSelected ? NexusBorder.base : NexusBorder.hair
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? NexusScale.pressLight : 1)
        .animation(NexusAnimation.press, value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - ViewModel

@MainActor
final class LinkURLViewModel: ObservableObject {
    @Published var contentType: LinkContentType
    @Published var urlText: String = ""
    @Published var collectionName: String = ""
    @Published var urlValidationError: String? = nil
    @Published var errorMessage: String? = nil
    @Published var isSubmitting = false

    init(contentType: LinkContentType = .website) {
        self.contentType = contentType
    }

    // MARK: - Computed

    var collectionNamePlaceholder: String {
        extractedDomain(from: urlText) ?? "My collection"
    }

    var effectiveCollectionName: String {
        let trimmed = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? collectionNamePlaceholder : trimmed
    }

    var isURLValid: Bool {
        guard !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }

    var canSubmit: Bool { isURLValid && !effectiveCollectionName.isEmpty }

    // MARK: - Actions

    /// Auto-fill URL from clipboard if it looks like a valid URL.
    /// Uses URL(string:).scheme check — not a string heuristic.
    func autoFillFromClipboard() {
        guard urlText.isEmpty else { return }
        guard let clip = UIPasteboard.general.string else { return }
        let trimmed = clip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme == "http" || url.scheme == "https" else { return }
        urlText = trimmed
        onURLChanged()
    }

    func pasteFromClipboard() {
        guard let clip = UIPasteboard.general.string else { return }
        let trimmed = clip.trimmingCharacters(in: .whitespacesAndNewlines)
        urlText = trimmed
        onURLChanged()
    }

    func onURLChanged() {
        // Clear previous validation error on every edit
        urlValidationError = nil
        // Derive collection name from domain if user hasn't typed one
        if collectionName.isEmpty, let domain = extractedDomain(from: urlText) {
            collectionName = domain.capitalized
        }
    }

    func submit(dismiss: () -> Void, onComplete: @escaping (UUID) -> Void) async {
        guard canSubmit else {
            urlValidationError = isURLValid ? nil : "Enter a valid URL starting with https://"
            return
        }

        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = effectiveCollectionName

        do {
            // Step 1: create the collection
            let collection = try await APIClient.shared.createCollection(name: name)

            // Step 2: queue ingestion — fire-and-forget (failures surfaced in Sources tab)
            Task {
                _ = try? await APIClient.shared.ingest(
                    url: url,
                    collectionId: collection.id,
                    contentType: contentType.apiValue
                )
            }

            // Step 3: dismiss and navigate
            dismiss()
            onComplete(collection.id)

        } catch {
            errorMessage = friendlyError(error)
        }
    }

    // MARK: - Helpers

    private func extractedDomain(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let host = url.host else { return nil }
        // Strip "www." prefix
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        // Use the first component before the first dot (e.g. "nytimes" from "nytimes.com")
        return domain.components(separatedBy: ".").first
    }

    private func friendlyError(_ error: Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .networkError:  return "No internet connection. Check your network and try again."
            case .unauthorized:  return "Session expired. Please sign out and sign back in."
            case .serverError:   return "Server error. Please try again in a moment."
            default:             return "Something went wrong. Please try again."
            }
        }
        return error.localizedDescription
    }
}
