import Combine
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isAuthenticated = false
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var userId: UUID?

    private let group = UserDefaults(suiteName: "group.app.nexus")
    private enum Key {
        static let accessToken  = "nexus_access_token"
        static let refreshToken = "nexus_refresh_token"
        static let userId       = "nexus_user_id"
    }

    private init() {
        // Restore persisted session so the user doesn't re-authenticate on every launch.
        // NOTE: SPEC §10 calls for Keychain storage. UserDefaults/app-group is acceptable
        // for beta; migrate to Keychain before public launch.
        if let token = group?.string(forKey: Key.accessToken),
           let idStr = group?.string(forKey: Key.userId),
           let uuid = UUID(uuidString: idStr) {
            accessToken = token
            refreshToken = group?.string(forKey: Key.refreshToken)
            userId = uuid
            isAuthenticated = true
        }
    }

    /// Call after a successful Apple or magic-link sign-in.
    func setSession(accessToken: String, refreshToken: String, userId: UUID) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        isAuthenticated = true
        group?.set(accessToken, forKey: Key.accessToken)
        group?.set(refreshToken, forKey: Key.refreshToken)
        group?.set(userId.uuidString, forKey: Key.userId)
    }

    /// Update only the access token (called after a successful token refresh).
    func updateAccessToken(_ token: String) {
        accessToken = token
        group?.set(token, forKey: Key.accessToken)
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        userId = nil
        isAuthenticated = false
        group?.removeObject(forKey: Key.accessToken)
        group?.removeObject(forKey: Key.refreshToken)
        group?.removeObject(forKey: Key.userId)
    }
}
