import Foundation

struct NexusCollection: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let framingParagraph: String?
    /// AI-generated, collection-specific starter questions (nil for older collections).
    var suggestedQuestions: [String]? = nil
    let createdBy: CreatedBy
    let sourceCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CreatedBy: String, Codable {
        case user, ai
    }
}
