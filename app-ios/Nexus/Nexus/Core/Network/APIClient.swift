import Foundation

/// Serializes token refreshes so N concurrent 401s trigger ONE refresh, not N.
/// Critical because Supabase rotates the refresh token — parallel refreshes
/// would invalidate each other and log the user out.
private actor RefreshGate {
    private var inFlight: Task<Bool, Never>?
    func run(_ op: @escaping @Sendable () async -> Bool) async -> Bool {
        if let inFlight { return await inFlight.value }
        let task = Task { await op() }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let refreshGate = RefreshGate()

    private var authToken: String? { AuthManager.shared.accessToken }

    /// Refresh the access token once (single-flighted). Returns true if the
    /// session was renewed and the caller should retry. On failure the session
    /// is left intact so the UI can surface a retry rather than a hard logout.
    private func attemptRefresh() async -> Bool {
        await refreshGate.run { [weak self] in
            guard let self else { return false }
            guard let rt = await MainActor.run(body: { AuthManager.shared.refreshToken }) else { return false }
            do {
                let resp = try await self.refreshAccessToken(refreshToken: rt)
                await MainActor.run {
                    AuthManager.shared.updateTokens(accessToken: resp.accessToken, refreshToken: resp.refreshToken)
                }
                return true
            } catch {
                return false
            }
        }
    }

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

    func deleteCollection(id: UUID) async throws {
        try await delete(.collection(id: id))
    }

    /// Permanently delete the account + all data (App Store 5.1.1(v)).
    func deleteAccount() async throws {
        try await delete(.authMe)
    }

    func ingest(url: String, collectionId: UUID, contentType: String = "article") async throws -> IngestResponse {
        let body = IngestRequest(url: url, collectionId: collectionId, contentType: contentType)
        return try await post(.ingest, body: body)
    }

    func submitFeedback(_ request: FeedbackRequest) async throws -> FeedbackSubmitResponse {
        try await post(.feedback, body: request)
    }

    /// Create a new user-owned collection (used by the URL paste sheet FRE flow).
    func createCollection(name: String) async throws -> NexusCollection {
        let body = CreateCollectionRequest(name: name)
        return try await post(.collections, body: body)
    }

    // MARK: - Artifacts (Create tab)

    /// List a collection's generated artifacts (newest first).
    func fetchArtifacts(in collectionId: UUID) async throws -> [Artifact] {
        try await get(.artifacts(collectionId: collectionId))
    }

    /// Generate a new artifact (quiz/paper) from the collection's sources.
    /// May take a few seconds — the backend generates synchronously on a
    /// Fireworks OSS model. Returns 502 if generation fails (surfaced as
    /// APIError.serverError).
    func createArtifact(kind: String, options: ArtifactOptions? = nil, in collectionId: UUID) async throws -> Artifact {
        try await post(.artifacts(collectionId: collectionId), body: ArtifactCreateRequest(kind: kind, options: options))
    }

    func deleteArtifact(id: UUID) async throws {
        try await delete(.artifact(id: id))
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

    #if DEBUG
    /// One-tap dev session — dev backend only (endpoint 404s in production).
    func devLogin() async throws -> AuthTokenResponse {
        try await post(.authDevLogin, body: EmptyRequest())
    }
    #endif

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

    // MARK: - Trending topics (FRE, no auth required)

    /// GET /v1/trending — up to 4 trending topic strings for onboarding chip row.
    ///
    /// Called at FRE load time before sign-in, so no Authorization header is sent.
    /// Returns topics from Google Trends RSS or a static fallback if unavailable.
    /// Never throws — on any failure the caller falls back to the static list.
    func fetchTrendingTopics() async -> TrendingTopicsResponse? {
        var req = URLRequest(url: Endpoint.trending.url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        // Intentionally no Authorization header: this endpoint is public.
        req.timeoutInterval = 5.0  // FRE load must not feel slow

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode)
        else { return nil }

        return try? decoder.decode(TrendingTopicsResponse.self, from: data)
    }

    // MARK: - Search

    /// GET /v1/search?q=<query>&mode=<mode>&limit=<limit>
    ///
    /// Passes query parameters via URL rather than a request body (GET semantics).
    /// Returns up to `limit` results ranked by hybrid FTS + semantic score.
    func search(
        query: String,
        mode: SearchRequest.SearchMode = .hybrid,
        limit: Int = 20,
        isRetry: Bool = false
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
        case 401:
            if !isRetry, await attemptRefresh() {
                return try await search(query: query, mode: mode, limit: limit, isRetry: true)
            }
            throw APIError.unauthorized
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
        isRetry: Bool = false,
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
            // Refresh + reopen the stream once on 401 (nothing has been streamed
            // yet at this point, so a clean retry is safe).
            if http.statusCode == 401, !isRetry, await attemptRefresh() {
                return try await streamSSE(endpoint, body: body, isRetry: true, onEvent: onEvent)
            }
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
            // Stop consuming on terminal events.
            // The backend may use "type" (chat endpoint) or "event" (research endpoint)
            // as the discriminant field — check both via nil-coalescing so the stream
            // terminates correctly regardless of which field the backend emits.
            let eventDiscriminant = (dict["event"] as? String) ?? (dict["type"] as? String)
            if eventDiscriminant == "done" || eventDiscriminant == "error" {
                break
            }
        }
    }

    // MARK: - Core

    private func perform<T: Decodable>(
        _ endpoint: Endpoint,
        method: String,
        body: (any Encodable)? = nil,
        isRetry: Bool = false
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
        case 401:
            // Access token likely expired — refresh once and retry transparently.
            if !isRetry, await attemptRefresh() {
                return try await perform(endpoint, method: method, body: body, isRetry: true)
            }
            throw APIError.unauthorized
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

struct CreateCollectionRequest: Encodable {
    let name: String
}

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

/// Response from GET /v1/trending.
struct TrendingTopicsResponse: Decodable {
    /// Up to 4 trending topic strings (Google Trends RSS or static fallback).
    let topics: [String]
    /// "trends" if live data was fetched, "static" if the fallback was used.
    let source: String
}

// Type-erased Encodable wrapper for heterogeneous bodies
private struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init(_ wrapped: any Encodable) { _encode = wrapped.encode }
    func encode(to encoder: Encoder) throws { try _encode(encoder) }
}
