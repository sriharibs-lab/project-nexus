import Foundation

enum Endpoint {
    // Priority: Info.plist "API_BASE_URL" → Xcode scheme env var → production.
    //
    // DEBUG now defaults to the PRODUCTION backend too (2026-10): the Render
    // deploy is stable, and the old LAN-IP fallback silently broke every dev
    // build whenever the Mac's IP drifted or the local server was down
    // ("couldn't load collections", Retry loops forever). To run against a
    // LOCAL backend, set API_BASE_URL (scheme env var or Info.plist) —
    // e.g. http://<mac-ip>:8000 — which takes priority over this fallback.
    static let productionBase = "https://nexus-api-bwrh.onrender.com"

    static var baseURL: String {
        if let plist = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String, !plist.isEmpty {
            return plist
        }
        if let env = ProcessInfo.processInfo.environment["API_BASE_URL"], !env.isEmpty {
            return env
        }
        return productionBase
    }

    // Auth
    case authMagicLink          // POST /v1/auth/magic-link — request OTP email
    case authVerifyOTP          // POST /v1/auth/verify-otp — verify OTP, get tokens
    case authApple              // POST /v1/auth/apple — exchange Apple identity token
    case authDevLogin           // POST /v1/auth/dev-login — DEBUG one-tap session (dev backend only)
    case authProvision          // POST /v1/auth/provision — upsert user after sign-in
    case authRefresh            // POST /v1/auth/refresh — refresh access token
    case authMe                 // GET  /v1/auth/me — current user profile

    // Collections
    case collections
    case collection(id: UUID)
    case items(collectionId: UUID)
    case item(collectionId: UUID, itemId: UUID)
    case ingest
    case feedback
    case research          // POST /v1/collections/research — SSE streaming
    case search            // GET /v1/search
    case chat(collectionId: UUID) // POST /v1/collections/{id}/chat — SSE streaming
    case interestTopics(limit: Int) // GET /v1/users/me/interest-topics
    case trending          // GET /v1/trending — live topic chips for FRE (no auth)
    case artifacts(collectionId: UUID) // GET list / POST create — Create tab
    case artifact(id: UUID)            // DELETE /v1/artifacts/{id}

    var path: String {
        switch self {
        case .authMagicLink:    return "/v1/auth/magic-link"
        case .authVerifyOTP:    return "/v1/auth/verify-otp"
        case .authApple:        return "/v1/auth/apple"
        case .authDevLogin:     return "/v1/auth/dev-login"
        case .authProvision:    return "/v1/auth/provision"
        case .authRefresh:      return "/v1/auth/refresh"
        case .authMe:           return "/v1/auth/me"
        case .collections:
            return "/v1/collections"
        case .collection(let id):
            return "/v1/collections/\(id.uuidString.lowercased())"
        case .items(let cid):
            return "/v1/collections/\(cid.uuidString.lowercased())/items"
        case .item(let cid, let iid):
            return "/v1/collections/\(cid.uuidString.lowercased())/items/\(iid.uuidString.lowercased())"
        case .ingest:
            return "/v1/ingest"
        case .feedback:
            return "/v1/feedback"
        case .research:
            return "/v1/collections/research"
        case .search:
            return "/v1/search"
        case .chat(let cid):
            return "/v1/collections/\(cid.uuidString.lowercased())/chat"
        case .interestTopics(let limit):
            return "/v1/users/me/interest-topics?limit=\(limit)"
        case .trending:
            return "/v1/trending"
        case .artifacts(let cid):
            return "/v1/collections/\(cid.uuidString.lowercased())/artifacts"
        case .artifact(let id):
            return "/v1/artifacts/\(id.uuidString.lowercased())"
        }
    }

    var url: URL {
        URL(string: Endpoint.baseURL + path)!
    }
}
