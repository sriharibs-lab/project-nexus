import Foundation

enum Endpoint {
    // Configured at launch via Info.plist key "API_BASE_URL";
    // falls back to localhost for simulator runs.
    static var baseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
            ?? "http://localhost:8000"
    }

    case authApple          // POST /v1/auth/apple — Apple Sign-In JWT exchange
    case collections
    case collection(id: UUID)
    case items(collectionId: UUID)
    case item(collectionId: UUID, itemId: UUID)
    case ingest
    case feedback
    case research          // POST /v1/collections/research — SSE streaming
    case search            // GET /v1/search
    case chat(collectionId: UUID) // POST /v1/collections/{id}/chat — SSE streaming

    var path: String {
        switch self {
        case .authApple:
            return "/v1/auth/apple"
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
        }
    }

    var url: URL {
        URL(string: Endpoint.baseURL + path)!
    }
}
