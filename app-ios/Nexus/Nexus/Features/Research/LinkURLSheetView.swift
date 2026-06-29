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

// MARK: - Sheet mode

/// Determines whether the sheet creates a new collection (create mode)
/// or adds a source to an existing one (add mode).
enum LinkURLSheetMode {
    /// Create mode: create a new collection then ingest the URL into it.
    /// `onComplete` is called with the new collection's UUID on success.
    case create(onComplete: (UUID) -> Void)
    /// Add mode: ingest the URL directly into an existing collection.
    /// `onDismiss` is called on success so the caller can refresh its sources list.
    case addToCollection(collectionId: UUID, onDismiss: () -> Void)
}

// MARK: - Sheet view

/// URL paste sheet opened by:
///  • The + button or link-type buttons in the FRE composer (create mode)
///  • The + toolbar button in SourcesTabView (add mode)
///
/// Create mode flow:
///  1. User pastes / types a URL
///  2. Collection name auto-fills from domain (editable)
///  3. Taps "Save to collection"
///  4. POST /v1/collections → creates the collection
///  5. POST /v1/ingest   → queues the URL (fire-and-forget)
///  6. Sheet dismisses and `onComplete(collectionId)` navigates to the new CollectionView
///
/// Add mode flow:
///  1. User pastes / types a URL
///  2. Collection name field is hidden (collection already exists)
///  3. Taps "Add"
///  4. POST /v1/ingest directly (no collection creation)
///  5. Sheet dismisses and `onDismiss()` triggers vm.load() to refresh Sources tab
struct LinkURLSheetView: View {
    /// Pre-selected content type (set by which button opened the sheet).
    let initialContentType: LinkContentType
    let mode: LinkURLSheetMode

    @StateObject private var vm: LinkURLViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Convenience initialisers

    /// Create mode initialiser (original FRE flow).
    init(
        initialContentType: LinkContentType = .website,
        onComplete: @escaping (UUID) -> Void
    ) {
        self.initialContentType = initialContentType
        self.mode = .create(onComplete: onComplete)
        _vm = StateObject(wrappedValue: LinkURLViewModel(
            contentType: initialContentType,
            isAddMode: false
        ))
    }

    /// Add-to-existing-collection mode initialiser (Sources tab '+' button).
    init(
        collectionId: UUID,
        initialContentType: LinkContentType = .website,
        onDismiss: @escaping () -> Void
    ) {
        self.initialContentType = initialContentType
        self.mode = .addToCollection(collectionId: collectionId, onDismiss: onDismiss)
        _vm = StateObject(wrappedValue: LinkURLViewModel(
            contentType: initialContentType,
            isAddMode: true
        ))
    }

    // MARK: - Computed helpers

    private var isAddMode: Bool {
        if case .addToCollection = mode { return true }
        return false
    }

    private var navigationTitle: String {
        isAddMode ? "Add a source" : "Start with a link"
    }

    private var submitLabel: String {
        isAddMode ? "Add" : "Save"
    }

    // MARK: - Body

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

                        // ── Collection name field (create mode only) ──
                        if !isAddMode {
                            collectionNameField
                        }

                        // ── Error banner ──
                        if let errMsg = vm.errorMessage {
                            errorBanner(message: errMsg) {
                                Task { await submitAction() }
                            }
                        }
                    }
                    .padding(.horizontal, NexusSpacing.standard)
                    .padding(.top, NexusSpacing.lg)
                    .padding(.bottom, NexusSpacing.xxl)
                }
            }
            .navigationTitle(navigationTitle)
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

    // MARK: - Submit action (dispatches to the right mode)

    private func submitAction() async {
        switch mode {
        case .create(let onComplete):
            await vm.submitCreate(dismiss: { dismiss() }, onComplete: onComplete)
        case .addToCollection(let collectionId, let onDismiss):
            await vm.submitAdd(
                collectionId: collectionId,
                dismiss: { dismiss() },
                onDismiss: onDismiss
            )
        }
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

    // MARK: - Collection name field (create mode)

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
        let canSubmit = isAddMode ? vm.isURLValid : vm.canSubmit
        return Button {
            Task { await submitAction() }
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
                    Text(submitLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 30)
                        .background(canSubmit ? Color.Nexus.accent : Color.Nexus.ghost)
                        .clipShape(Capsule())
                }
            }
            .animation(NexusAnimation.element, value: vm.isSubmitting)
        }
        .disabled(!canSubmit || vm.isSubmitting)
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

    /// Whether the sheet is in add-to-existing-collection mode.
    let isAddMode: Bool

    init(contentType: LinkContentType = .website, isAddMode: Bool = false) {
        self.contentType = contentType
        self.isAddMode = isAddMode
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

    /// In create mode: URL must be valid AND effectiveCollectionName must be non-empty.
    /// In add mode: only URL validity matters (no collection name field).
    var canSubmit: Bool {
        isAddMode ? isURLValid : (isURLValid && !effectiveCollectionName.isEmpty)
    }

    // MARK: - Actions

    /// Auto-fill URL from clipboard if it looks like a valid URL.
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
        // Derive collection name from domain if user hasn't typed one (create mode)
        if !isAddMode, collectionName.isEmpty, let domain = extractedDomain(from: urlText) {
            collectionName = domain.capitalized
        }
    }

    // MARK: - Submit: create mode

    func submitCreate(dismiss: () -> Void, onComplete: @escaping (UUID) -> Void) async {
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

    // MARK: - Submit: add mode

    /// Posts directly to /v1/ingest with the provided collectionId.
    /// No collection creation step — the collection already exists.
    func submitAdd(collectionId: UUID, dismiss: () -> Void, onDismiss: @escaping () -> Void) async {
        guard isURLValid else {
            urlValidationError = "Enter a valid URL starting with https://"
            return
        }

        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let url = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            _ = try await APIClient.shared.ingest(
                url: url,
                collectionId: collectionId,
                contentType: contentType.apiValue
            )
            dismiss()
            onDismiss()
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
