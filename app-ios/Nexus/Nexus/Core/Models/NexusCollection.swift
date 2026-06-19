import Foundation

struct NexusCollection: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let framingParagraph: String?
    let createdBy: CreatedBy
    let sourceCount: Int
    let createdAt: Date
    let updatedAt: Date

    enum CreatedBy: String, Codable {
        case user, ai
    }
}
