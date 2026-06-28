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

    /// Send a magic-link OTP email via our backend (keeps Supabase service key server-side).
    func sendMagicLink(email: String) async throws {
        let body = MagicLinkRequest(email: email)
        let _: MagicLinkResponse = try await post(.authMagicLink, body: body)
    }

    /// Verify a 6-digit OTP code and receive session tokens.
    func verifyOTP(email: String, token: String) async throws -> AuthTokenResponse {
        let body = OTPVerifyRequest(email: email, token: token)
        return try await post(.authVerifyOTP, body: body)
    }

    /// Exchange an Apple identity token for Nexus session tokens.
    func signInWithApple(identityToken: String) async throws -> AuthTokenResponse {
        let body = AppleSignInRequest(identityToken: identityToken)
        return try await post(.authApple, body: body)
    }

    /// Upsert the authenticated user in the Nexus DB. Call after every sign-in.
    @discardableResult
    func provisionUser() async throws -> ProvisionUserResponse {
        return try await post(.authProvision, body: EmptyRequest())
    }

    /// Refresh the access token using the stored refresh token.
    func refreshAccessToken(refreshToken: String) async throws -> TokenRefreshResponse {
        let body = TokenRefreshRequest(refreshToken: refreshToken)
        return try await post(.authRefresh, body: body)
    }

    // MARK: - User profile

    /// GET /v1/users/me/interest-topics?limit=<n>
    ///
    /// Returns the authenticated user's top interest topics, personalised
    /// from their reading history. Falls back to curated defaults server-side
    /// when the user has no saved content yet — so the response is always
    /// non-empty and safe to use directly in FRERotatingWord.
    func fetchInterestTopics(limit: Int = 5) async throws -> InterestTopicsResponse {
        try await get(.interestTopics(limit: limit))
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

struct InterestTopicsResponse: Decodable {
    /// Display-ready topic strings sorted by interest weight descending.
    /// Never empty — server falls back to curated defaults for new users.
    let topics: [String]
    /// true if topics come from the user's real reading history;
    /// false if they are the generic FRE defaults.
    let hasProfile: Bool
}

struct EmptyResponse: Codable {
    init() {}
    init(from decoder: Decoder) throws {}
}

/// An empty body for POST endpoints that take no payload.
struct EmptyRequest: Encodable {}

// MARK: - Auth types

struct MagicLinkRequest: Encodable {
    let email: String
}

struct MagicLinkResponse: Decodable {
    let message: String
}

struct OTPVerifyRequest: Encodable {
    let email: String
    let token: String
}

struct AppleSignInRequest: Encodable {
    let identityToken: String
}

/// Returned by /auth/verify-otp and /auth/apple (sign-in endpoints that include Nexus user_id).
struct AuthTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    /// Nexus DB user UUID returned as a string; decoded directly from snake_case JSON field.
    let userId: String
    let expiresIn: Int

    /// Convenience: parse userId string to UUID, falling back to a new UUID on malformed input.
    var userUUID: UUID { UUID(uuidString: userId) ?? UUID() }
}

struct TokenRefreshRequest: Encodable {
    let refreshToken: String
}

/// Returned by /auth/refresh (no user_id — caller already has it from sign-in).
struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
}

struct ProvisionUserResponse: Decodable {
    struct UserProfile: Decodable {
        let id: String
        let supabaseId: String
        let email: String
    }
    let user: UserProfile
    let isNew: Bool
}

// Type-erased Encodable wrapper for heterogeneous bodies
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: any Encodable) { _encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
