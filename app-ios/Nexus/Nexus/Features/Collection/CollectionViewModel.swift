import Foundation

@MainActor
final class CollectionViewModel: ObservableObject {
    let collection: NexusCollection

    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published var error: APIError?

    init(collection: NexusCollection) {
        self.collection = collection
    }

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
}
