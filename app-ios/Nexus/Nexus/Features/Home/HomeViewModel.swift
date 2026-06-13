import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var collections: [NexusCollection] = []
    @Published private(set) var isLoading = false
    @Published var error: APIError?

    func load() async {
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
}
