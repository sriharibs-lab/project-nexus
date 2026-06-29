import Foundation

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private var authToken: String? { AuthManager.shared.accessToken }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    // MARK: - Generic request

    func get<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        try await perform(endpoint, method: "GET")
    }

    func post<B: Encodable, T: Decodable>(_ endpoint: Endpoint, body: B) async throws -> T {
        try await perform(endpoint, method: "POST", body: body)
    }

    func delete(_ endpoint: Endpoint) async throws {
        let _: EmptyResponse = try await perform(endpoint, method: "DELETE")
    }

    // MARK: - Typed API calls

    func fetchCollections() async throws -> [NexusCollection] {
        try await get(.collections)
    }

    func fetchItems(in collectionId: UUID) async throws -> [Item] {
        try await get(.items(collectionId: collectionId))
    }

    /// Fetch a single item including its raw extracted text (for Reader view).
    func fetchItem(id itemId: UUID, in collectionId: UUID) async throws -> Item {
        try await get(.item(collectionId: collectionId, itemId: itemId))
    }

    /// Delete a saved source from a collection.
    /// Calls DELETE /v1/collections/{collectionId}/items/{itemId}.
    /// The backend returns 204 No Content on success.
    func deleteItem(id itemId: UUID, in collectionId: UUID) async throws {
        try await delete(.item(collectionId: collectionId, itemId: itemId))
    }

    func ingest(url: String, collectionId: UUID, contentType: String = "article") async throws -> IngestResponse {
        let body = IngestRequest(url: url, collectionId: collectionId, contentType: contentType)
        return try await post(.ingest, body: body)
    }

    func submitFeedback(_ request: FeedbackRequest) async throws -> FeedbackSubmitResponse {
        try await post(.feedback, body: request)
    }

    // MARK: - Auth

    /// Exchange an Apple identity token for a Nexus access token.
    ///
    /// Call this immediately after ASAuthorization succeeds, passing the
    /// identityToken JWT from ASAuthorizationAppleIDCredential. Never use
    /// the raw `cred.user` string as a bearer token — it is an opaque user
    /// identifier, not a signed credential the server can verify.
    func signInWithApple(
        identityToken: String,
        userId: String,
        email: String?,
        fullName: String?
    ) async throws -> AppleSignInResponse {
        let body = AppleSignInRequest(
            identityToken: identityToken,
            userId: userId,
            email: email,
            fullName: fullName
        )
        return try await post(.authApple, body: body)
    }

    // MARK: - Search

    /// GET /v1/search?q=<query>&mode=<mode>&limit=<limit>
    ///
    /// Passes query parameters via URL rather than a request body (GET semantics).
    /// Returns up to `limit` results ranked by hybrid FTS + semantic score.
    func search(
        query: String,
        mode: SearchRequest.SearchMode = .hybrid,
        limit: Int = 20
    ) async throws -> SearchResponse {
        guard var components = URLComponents(url: Endpoint.search.url, resolvingAgainstBaseURL: false) else {
            throw APIError.unknown
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "mode", value: mode.rawValue),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components.url else { throw APIError.unknown }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        switch http.statusCode {
        case 200...299:
            do { return try decoder.decode(SearchResponse.self, from: data) }
            catch { throw APIError.decodingError(error) }
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default:  throw APIError.serverError(http.statusCode)
        }
    }

    // MARK: - SSE Streaming

    /// Opens a POST SSE stream and calls `onEvent` for each parsed JSON payload.
    /// Returns when the stream closes or an error event is received.
    /// Throws on network/HTTP errors; SSE-level errors are surfaced via the callback.
    func streamSSE<B: Encodable>(
        _ endpoint: Endpoint,
        body: B,
        onEvent: @escaping (Result<[String: Any], Error>) -> Void
    ) async throws {
        var req = URLRequest(url: endpoint.url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try encoder.encode(AnyEncodable(body))

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        guard (200...299).contains(http.statusCode) else {
            switch http.statusCode {
            case 401: throw APIError.unauthorized
            case 404: throw APIError.notFound
            default:  throw APIError.serverError(http.statusCode)
            }
        }

        // Parse SSE: lines are "data: <json>\n\n"
        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            guard let data = jsonStr.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            onEvent(.success(dict))
            // Stop consuming on terminal events
            if let event = dict["event"] as? String, event == "done" || event == "error" {
                break
            }
        }
    }

    // MARK: - Core

    private func perform<T: Decodable>(
        _ endpoint: Endpoint,
        method: String,
        body: (any Encodable)? = nil
    ) async throws -> T {
        var req = URLRequest(url: endpoint.url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

        switch http.statusCode {
        case 200...299:
            if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T { return empty }
            do { return try decoder.decode(T.self, from: data) }
            catch { throw APIError.decodingError(error) }
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        default:  throw APIError.serverError(http.statusCode)
        }
    }
}

// MARK: - Request / Response types

// MARK: - Apple Sign-In

struct AppleSignInRequest: Encodable {
    let identityToken: String
    let userId: String
    let email: String?
    let fullName: String?
}

struct AppleSignInUserProfile: Decodable {
    let id: String
    let supabaseId: String
    let email: String
}

struct AppleSignInResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let user: AppleSignInUserProfile
    let isNew: Bool
}

struct ResearchRequestBody: Encodable {
    let topic: String
    let name: String?
}

struct IngestRequest: Encodable {
    let url: String
    let collectionId: UUID
    let contentType: String
}

struct IngestResponse: Decodable {
    let jobId: String
    let status: String
    let message: String
}

struct FeedbackRequest: Encodable {
    let text: String
    let screenshotUrl: String?
    let category: String
    let appVersion: String?
    let iosVersion: String?
    let deviceModel: String?
}

struct FeedbackSubmitResponse: Decodable {
    let id: String
    let status: String
}

struct EmptyResponse: Codable {
    init() {}
    init(from decoder: Decoder) throws {}
}

// Type-erased Encodable wrapper for heterogeneous bodies
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: any Encodable) { _encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
