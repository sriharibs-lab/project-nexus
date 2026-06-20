import Foundation

// MARK: - Search request

struct SearchRequest: Encodable {
    // Encoded as query params, not a body — see APIClient.search()
    let q: String
    let mode: SearchMode
    let limit: Int

    enum SearchMode: String, Encodable {
        case hybrid, fts, semantic
    }
}

// MARK: - Search response

struct SearchResponse: Decodable {
    let query: String
    let mode: String
    let results: [SearchResultItem]
    let total: Int
    let embeddingAvailable: Bool
}

struct SearchResultItem: Decodable, Identifiable, Hashable {
    let itemId: UUID
    let title: String?
    let url: String
    let summary: String?
    let contentType: String
    let ingestStatus: String
    let tags: [String]
    let score: Double
    let ftsRank: Double?
    let semanticScore: Double?

    // Identifiable conformance
    var id: UUID { itemId }

    // Convenience: extract domain label for display
    var domain: String? {
        guard let host = URL(string: url)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    // Percentage match label (0-100)
    var scorePercent: Int {
        Int((score * 100).rounded())
    }
}
