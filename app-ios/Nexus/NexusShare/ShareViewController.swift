import UIKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Entry point (UIKit shell; SwiftUI handles all UI)

final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.984, green: 0.984, blue: 0.988, alpha: 1)
        extractURL { [weak self] url in
            DispatchQueue.main.async { self?.mount(url: url) }
        }
    }

    private func mount(url: URL?) {
        let token = UserDefaults(suiteName: "group.app.nexus")?.string(forKey: "nexus_access_token")
        let host = UIHostingController(rootView: NexusShareView(
            sharedURL: url,
            authToken: token,
            onDone:   { [weak self] in self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil) },
            onCancel: { [weak self] in self?.extensionContext?.cancelRequest(withError: NSError(domain: "app.nexus", code: 0)) }
        ))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func extractURL(completion: @escaping (URL?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments else { completion(nil); return }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { value, _ in
                    completion(value as? URL)
                }
                return
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { value, _ in
                    let url = (value as? String).flatMap(URL.init(string:))
                    completion(url)
                }
                return
            }
        }
        completion(nil)
    }
}

// MARK: - SwiftUI UI

private struct NexusShareView: View {
    let sharedURL: URL?
    let authToken: String?
    let onDone: () -> Void
    let onCancel: () -> Void

    @State private var collections: [ShareCollection] = []
    @State private var selectedId: String? = nil
    @State private var loadingCollections = false
    @State private var saving = false
    @State private var saved = false
    @State private var errorMessage: String? = nil

    // Design tokens (hardcoded — extension can't import the main app's DesignSystem module)
    private let accent    = Color(red: 0.439, green: 0.329, blue: 0.671) // #7054AB
    private let ink       = Color(red: 0.075, green: 0.055, blue: 0.102) // #130E1A
    private let muted     = Color(red: 0.075, green: 0.055, blue: 0.102).opacity(0.48)
    private let ghost     = Color(red: 0.075, green: 0.055, blue: 0.102).opacity(0.28)
    private let page      = Color(red: 0.984, green: 0.984, blue: 0.988) // #FBFBFC
    private let card      = Color.white
    private let border    = Color(red: 0.075, green: 0.055, blue: 0.102).opacity(0.10)

    var body: some View {
        ZStack {
            page.ignoresSafeArea()
            VStack(spacing: 0) {
                handle
                if saved {
                    successView.padding(.top, 32)
                } else if authToken == nil {
                    notLoggedInView.padding(.top, 32)
                } else {
                    mainContent
                }
                Spacer()
            }
        }
        .task { await loadCollections() }
    }

    // MARK: - Handle

    private var handle: some View {
        Capsule()
            .fill(border)
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 18)
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header row
            HStack {
                Text("Save to Nexus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ink)
                Spacer()
                Button("Cancel") { onCancel() }
                    .font(.system(size: 15))
                    .foregroundColor(accent)
            }
            .padding(.horizontal, 20)

            // URL preview card
            if let url = sharedURL {
                urlCard(url)
            } else {
                Text("No URL found in this share.")
                    .font(.system(size: 14))
                    .foregroundColor(muted)
                    .padding(.horizontal, 20)
            }

            // Collection picker
            VStack(alignment: .leading, spacing: 10) {
                Text("COLLECTION")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.6)
                    .foregroundColor(muted)
                    .padding(.horizontal, 20)

                if loadingCollections {
                    HStack { Spacer(); ProgressView().tint(accent); Spacer() }
                        .padding(.vertical, 12)
                } else if collections.isEmpty {
                    Text("No collections. Create one in Nexus first.")
                        .font(.system(size: 14))
                        .foregroundColor(muted)
                        .padding(.horizontal, 20)
                } else {
                    collectionList
                }
            }

            // Error
            if let msg = errorMessage {
                Text(msg)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
            }

            // Save button
            if sharedURL != nil {
                saveButton
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - URL card

    private func urlCard(_ url: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "link")
                .font(.system(size: 14))
                .foregroundColor(accent)
                .frame(width: 32, height: 32)
                .background(accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(url.host ?? url.absoluteString)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ink)
                    .lineLimit(1)
                Text(url.absoluteString)
                    .font(.system(size: 12))
                    .foregroundColor(muted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(14)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 0.5))
        .padding(.horizontal, 20)
    }

    // MARK: - Collection list

    private var collectionList: some View {
        VStack(spacing: 0) {
            ForEach(collections) { col in
                Button {
                    selectedId = col.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(col.name)
                                .font(.system(size: 15))
                                .foregroundColor(ink)
                            Text("\(col.sourceCount) source\(col.sourceCount == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundColor(muted)
                        }
                        Spacer()
                        if selectedId == col.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(accent)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(ghost)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                if col.id != collections.last?.id {
                    Divider().padding(.leading, 20)
                }
            }
        }
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 0.5))
        .padding(.horizontal, 20)
    }

    // MARK: - Save button

    private var canSave: Bool {
        sharedURL != nil && selectedId != nil && !saving
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack {
                if saving {
                    ProgressView().tint(.white)
                } else {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(canSave ? accent : ghost)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!canSave)
        .animation(.easeInOut(duration: 0.15), value: canSave)
    }

    // MARK: - Success view

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(accent)
            Text("Saved to Nexus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(ink)
            if let col = collections.first(where: { $0.id == selectedId }) {
                Text(col.name)
                    .font(.system(size: 14))
                    .foregroundColor(muted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Not logged in

    private var notLoggedInView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundColor(muted)
            VStack(spacing: 6) {
                Text("Not logged in")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(ink)
                Text("Open the Nexus app and sign in,\nthen try sharing again.")
                    .font(.system(size: 14))
                    .foregroundColor(muted)
                    .multilineTextAlignment(.center)
            }
            Button("Dismiss") { onCancel() }
                .font(.system(size: 15))
                .foregroundColor(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Network

    private func loadCollections() async {
        guard let token = authToken else { return }
        loadingCollections = true
        defer { loadingCollections = false }

        let base = UserDefaults(suiteName: "group.app.nexus")?.string(forKey: "nexus_api_base") ?? "http://localhost:8000"
        guard let url = URL(string: "\(base)/v1/collections") else { return }

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            collections = try decoder.decode([ShareCollection].self, from: data)
            selectedId = collections.first?.id
        } catch {
            errorMessage = "Couldn't load collections."
        }
    }

    private func save() async {
        guard let token = authToken,
              let urlStr = sharedURL?.absoluteString,
              let colId = selectedId else { return }

        saving = true
        errorMessage = nil
        defer { saving = false }

        let base = UserDefaults(suiteName: "group.app.nexus")?.string(forKey: "nexus_api_base") ?? "http://localhost:8000"
        guard let endpoint = URL(string: "\(base)/v1/ingest") else { return }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "url": urlStr,
            "collection_id": colId,
            "content_type": "article",
        ])

        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { errorMessage = "Unknown error."; return }
            if (200...299).contains(http.statusCode) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { saved = true }
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                onDone()
            } else {
                errorMessage = http.statusCode == 401 ? "Session expired. Sign into Nexus again." : "Save failed (\(http.statusCode)). Try again."
            }
        } catch {
            errorMessage = "Network error. Check your connection."
        }
    }
}

// MARK: - Models

private struct ShareCollection: Identifiable, Decodable {
    let id: String
    let name: String
    let sourceCount: Int
}
