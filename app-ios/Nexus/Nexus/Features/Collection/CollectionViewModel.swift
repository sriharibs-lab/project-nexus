import Combine
import Foundation

@MainActor
final class CollectionViewModel: ObservableObject {
    let collection: NexusCollection

    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published var error: APIError?
    /// Non-nil when a swipe-to-delete API call fails; shown as an alert in CollectionView.
    @Published var deleteError: APIError?

    init(collection: NexusCollection) {
        self.collection = collection
    }

    // MARK: - Load sources

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await APIClient.shared.fetchItems(in: collection.id)
        } catch let e as APIError {
            error = e
        } catch {
            self.error = .networkError(error)
        }
    }

    // MARK: - Delete a source (swipe-to-delete)
    //
    // Optimistic removal: strip the item from the local list immediately so the
    // UI responds at once (no waiting for the network). If the API call fails,
    // re-insert the item at its original position and surface deleteError to
    // CollectionView, which shows an alert.
    //
    // This avoids a janky "item reappears" flash on success while still giving
    // the user accurate feedback on failure.

    func delete(item: Item) async {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }

        // Optimistic removal
        items.remove(at: idx)

        do {
            try await APIClient.shared.deleteItem(id: item.id, in: collection.id)
        } catch let e as APIError {
            // Roll back: re-insert at original position
            items.insert(item, at: min(idx, items.count))
            deleteError = e
        } catch {
            items.insert(item, at: min(idx, items.count))
            deleteError = .networkError(error)
        }
    }
}
