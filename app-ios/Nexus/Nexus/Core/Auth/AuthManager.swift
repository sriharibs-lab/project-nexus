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

    // Session persists in BOTH stores:
    //  • standard UserDefaults — always works, the durable copy. The app-group
    //    suite silently fails to persist when the App Groups entitlement is
    //    missing (which it was — caused re-login on every launch, 2026-07-11).
    //  • app-group suite — best-effort, read by the Share Extension once the
    //    entitlement actually lands (PARKING_LOT).
    // NOTE: SPEC §10 calls for Keychain storage. UserDefaults is acceptable
    // for beta; migrate to Keychain before public launch.
    private let store = UserDefaults.standard
    private let group = UserDefaults(suiteName: "group.app.nexus")
    private enum Key {
        static let accessToken  = "nexus_access_token"
        static let refreshToken = "nexus_refresh_token"
        static let userId       = "nexus_user_id"
        static let displayName  = "nexus_display_name"
        static let email        = "nexus_email"
    }

    private func read(_ key: String) -> String? {
        store.string(forKey: key) ?? group?.string(forKey: key)
    }

    private func write(_ value: String, _ key: String) {
        store.set(value, forKey: key)
        group?.set(value, forKey: key)
    }

    private func clear(_ key: String) {
        store.removeObject(forKey: key)
        group?.removeObject(forKey: key)
    }

    private init() {
        // Restore persisted session so the user doesn't re-authenticate on every launch.
        if let token = read(Key.accessToken),
           let idStr = read(Key.userId),
           let uuid = UUID(uuidString: idStr) {
            accessToken = token
            refreshToken = read(Key.refreshToken)
            userId = uuid
            isAuthenticated = true
            displayName = read(Key.displayName) ?? ""
            email = read(Key.email) ?? ""
        }
    }

    /// Call after a successful Apple or magic-link sign-in.
    func setSession(accessToken: String, refreshToken: String? = nil, userId: UUID, displayName: String = "", email: String = "") {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userId = userId
        isAuthenticated = true
        write(accessToken, Key.accessToken)
        if let rt = refreshToken {
            write(rt, Key.refreshToken)
        }
        write(userId.uuidString, Key.userId)
        // Only overwrite stored name/email if non-empty — Apple only provides them on first sign-in
        if !displayName.isEmpty {
            self.displayName = displayName
            write(displayName, Key.displayName)
        }
        if !email.isEmpty {
            self.email = email
            write(email, Key.email)
        }
    }

    /// Update only the access token (called after a successful token refresh).
    func updateAccessToken(_ token: String) {
        accessToken = token
        write(token, Key.accessToken)
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        userId = nil
        isAuthenticated = false
        displayName = ""
        email = ""
        [Key.accessToken, Key.refreshToken, Key.userId, Key.displayName, Key.email].forEach(clear)
    }

    // MARK: - Derived

    /// Single uppercase letter for the avatar circle. Falls back to "N" (Nexus).
    var avatarInitial: String {
        if let first = displayName.first { return String(first).uppercased() }
        if let first = email.first { return String(first).uppercased() }
        return "N"
    }
}
