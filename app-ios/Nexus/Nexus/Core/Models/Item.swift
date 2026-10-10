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
    // decoded from list responses — that is expected and must not throw
    // DecodingError.keyNotFound (hence var with default nil, matching tags pattern).
    var rawContent: String? = nil
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

    /// Title for display: the extracted title, else a humanized form of the URL
    /// ("Live Cricket Score", "example.com") — never the raw URL (feedback
    /// 2026-10-09: a bot-blocked page showed its full URL as the headline).
    var displayTitle: String { title?.isEmpty == false ? title! : Item.humanizeURLTitle(url) }

    static func humanizeURLTitle(_ raw: String) -> String {
        guard let u = URL(string: raw) else { return raw }
        let segments = u.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        for seg in segments.reversed() {
            var s = seg
            if let dot = s.lastIndex(of: "."), s.distance(from: dot, to: s.endIndex) <= 6 { s = String(s[..<dot]) }
            let words = s.split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == "+" })
                .map(String.init)
                .filter { !$0.isEmpty && !$0.allSatisfy(\.isNumber) }
            if words.count >= 1, words.joined().count >= 3 {
                return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
            }
        }
        let host = (u.host ?? raw).replacingOccurrences(of: "www.", with: "")
        return host
    }
}
