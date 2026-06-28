import Combine
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var displayName: String = ""
    @Published private(set) var email: String = ""
    private(set) var accessToken: String?
    private(set) var refreshToken: String?
    private(set) var userId: UUID?

    private let group = UserDefaults(suiteName: "group.app.nexus")
    private enum Key {
        static let accessToken  = "nexus_access_token"
        static let refreshToken = "nexus_refresh_token"
        static let userId       = "nexus_user_id"
        static let displayName  = "nexus_display_name"
        static let email        = "nexus_email"
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
            displayName = group?.string(forKey: Key.displayName) ?? ""
            email = group?.string(forKey: Key.email) ?? ""
        }
    }

    /// Call after a successful Apple or magic-link sign-in.
    func setSession(accessToken: String, refreshToken: String? = nil, userId: UUID, displayName: String = "", email: String = "") {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        isAuthenticated = true
        group?.set(accessToken, forKey: Key.accessToken)
        if let rt = refreshToken {
            group?.set(rt, forKey: Key.refreshToken)
        }
        group?.set(userId.uuidString, forKey: Key.userId)
        // Only overwrite stored name/email if non-empty — Apple only provides them on first sign-in
        if !displayName.isEmpty {
            self.displayName = displayName
            group?.set(displayName, forKey: Key.displayName)
        }
        if !email.isEmpty {
            self.email = email
            group?.set(email, forKey: Key.email)
        }
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
        displayName = ""
        email = ""
        group?.removeObject(forKey: Key.accessToken)
        group?.removeObject(forKey: Key.refreshToken)
        group?.removeObject(forKey: Key.userId)
        group?.removeObject(forKey: Key.displayName)
        group?.removeObject(forKey: Key.email)
    }

    // MARK: - Derived

    /// Single uppercase letter for the avatar circle. Falls back to "N" (Nexus).
    var avatarInitial: String {
        if let first = displayName.first { return String(first).uppercased() }
        if let first = email.first { return String(first).uppercased() }
        return "N"
    }
}
