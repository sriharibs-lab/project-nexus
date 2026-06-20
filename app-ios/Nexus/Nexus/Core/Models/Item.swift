import Foundation

struct Item: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let url: String
    let title: String?
    let contentType: ContentType
    let summary: String?
    let insights: [String]?
    // tags defaults to [] so Codable never throws DecodingError.keyNotFound
    // when the backend omits the key (backend ItemResponse already returns [] by default)
    var tags: [String] = []
    // rawContent is the full extracted text; returned only by GET /items/{id},
    // not the list endpoint (avoids large payload on list). Will be nil when
    // decoded from list responses — that is expected.
    let rawContent: String?
    let ingestStatus: IngestStatus
    let createdAt: Date
    let updatedAt: Date

    enum ContentType: String, Codable {
        case article, podcast, video, youtube, thread, blog, announcement, other

        var icon: String {
            switch self {
            case .article:      return "doc.text"
            case .podcast:      return "mic"
            case .video:        return "play.rectangle"
            case .youtube:      return "play.rectangle.fill"
            case .thread:       return "bubble.left.and.bubble.right"
            case .blog:         return "text.alignleft"
            case .announcement: return "megaphone"
            case .other:        return "link"
            }
        }
    }

    enum IngestStatus: String, Codable {
        case pending, processing, completed, failed

        var isReady: Bool { self == .completed }
    }
}
