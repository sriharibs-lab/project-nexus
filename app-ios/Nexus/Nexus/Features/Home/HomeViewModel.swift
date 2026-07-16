import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var collections: [NexusCollection] = []
    @Published private(set) var isLoading = false
    @Published var error: APIError?
    /// Non-nil when a swipe-to-delete API call fails; shown as an alert.
    @Published var deleteError: APIError?
    /// Live search query (Claude-style bottom search bar).
    @Published var query = ""

    /// Collections matching the current query (client-side filter).
    var visibleCollections: [NexusCollection] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return collections }
        return collections.filter { $0.name.lowercased().contains(q) }
    }

    #if DEBUG
    /// Simulator preview harness: seed sample data, never hit the API.
    private var isPreview = false
    convenience init(previewCollections: [NexusCollection]) {
        self.init()
        collections = previewCollections
        isPreview = true
    }
    #endif

    func load() async {
        #if DEBUG
        guard !isPreview else { return }
        #endif
        isLoading = true
        defer { isLoading = false }
        do {
            collections = try await APIClient.shared.fetchCollections()
        } catch let e as APIError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    /// Swipe-to-delete: optimistic removal, rollback + alert on failure
    /// (mirrors CollectionViewModel.delete).
    func delete(_ collection: NexusCollection) async {
        guard let idx = collections.firstIndex(where: { $0.id == collection.id }) else { return }
        collections.remove(at: idx)

        #if DEBUG
        guard !isPreview else { return }
        #endif

        do {
            try await APIClient.shared.deleteCollection(id: collection.id)
        } catch let e as APIError {
            collections.insert(collection, at: min(idx, collections.count))
            deleteError = e
        } catch {
            collections.insert(collection, at: min(idx, collections.count))
            deleteError = .networkError(error)
        }
    }
}
