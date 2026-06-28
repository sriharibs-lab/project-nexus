import Combine
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var displayName: String = ""
    @Published private(set) var email: String = ""
    private(set) var accessToken: String?
    private(set) var userId: UUID?

    private let group = UserDefaults(suiteName: "group.app.nexus")
    private enum Key {
        static let token       = "nexus_access_token"
        static let userId      = "nexus_user_id"
        static let displayName = "nexus_display_name"
        static let email       = "nexus_email"
    }

    private init() {
        // Restore persisted session so the user doesn't re-authenticate on every launch
        if let token = group?.string(forKey: Key.token),
           let idStr = group?.string(forKey: Key.userId),
           let uuid = UUID(uuidString: idStr) {
            accessToken = token
            userId = uuid
            isAuthenticated = true
            displayName = group?.string(forKey: Key.displayName) ?? ""
            email = group?.string(forKey: Key.email) ?? ""
        }
    }

    func setSession(token: String, userId: UUID, displayName: String = "", email: String = "") {
        accessToken = token
        self.userId = userId
        isAuthenticated = true
        // Only overwrite stored name/email if non-empty — Apple only provides them on first sign-in
        if !displayName.isEmpty {
            self.displayName = displayName
            group?.set(displayName, forKey: Key.displayName)
        }
        if !email.isEmpty {
            self.email = email
            group?.set(email, forKey: Key.email)
        }
        group?.set(token, forKey: Key.token)
        group?.set(userId.uuidString, forKey: Key.userId)
    }

    func signOut() {
        accessToken = nil
        userId = nil
        isAuthenticated = false
        displayName = ""
        email = ""
        group?.removeObject(forKey: Key.token)
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
