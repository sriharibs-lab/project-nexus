import Combine
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isAuthenticated = false
    private(set) var accessToken: String?
    private(set) var userId: UUID?

    private init() {}

    func setSession(token: String, userId: UUID) {
        accessToken = token
        self.userId = userId
        isAuthenticated = true
    }

    func signOut() {
        accessToken = nil
        userId = nil
        isAuthenticated = false
    }
}
