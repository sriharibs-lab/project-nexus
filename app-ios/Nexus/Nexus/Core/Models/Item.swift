import Foundation

struct Item: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let url: String
    let title: String?
    let contentType: ContentType
    let summary: String?
    let insights: [String]?
    let ingestStatus: IngestStatus
    let createdAt: Date
    let updatedAt: Date

    enum ContentType: String, Codable {
        case article, podcast, video, thread, blog, announcement, other

        var icon: String {
            switch self {
            case .article:      return "doc.text"
            case .podcast:      return "mic"
            case .video:        return "play.rectangle"
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
