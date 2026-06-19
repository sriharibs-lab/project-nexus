import Combine
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isAuthenticated = false
    private(set) var accessToken: String?
    private(set) var userId: UUID?

    private let group = UserDefaults(suiteName: "group.app.nexus")
    private enum Key {
        static let token  = "nexus_access_token"
        static let userId = "nexus_user_id"
    }

    private init() {
        // Restore persisted session so the user doesn't re-authenticate on every launch
        if let token = group?.string(forKey: Key.token),
           let idStr = group?.string(forKey: Key.userId),
           let uuid = UUID(uuidString: idStr) {
            accessToken = token
            userId = uuid
            isAuthenticated = true
        }
    }

    func setSession(token: String, userId: UUID) {
        accessToken = token
        self.userId = userId
        isAuthenticated = true
        group?.set(token, forKey: Key.token)
        group?.set(userId.uuidString, forKey: Key.userId)
    }

    func signOut() {
        accessToken = nil
        userId = nil
        isAuthenticated = false
        group?.removeObject(forKey: Key.token)
        group?.removeObject(forKey: Key.userId)
    }
}
