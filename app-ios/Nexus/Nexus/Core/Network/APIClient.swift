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

    func ingest(url: String, collectionId: UUID, contentType: String = "article") async throws -> IngestResponse {
        let body = IngestRequest(url: url, collectionId: collectionId, contentType: contentType)
        return try await post(.ingest, body: body)
    }

    func submitFeedback(_ request: FeedbackRequest) async throws -> EmptyResponse {
        try await post(.feedback, body: request)
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
