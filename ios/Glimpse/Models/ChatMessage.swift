import Foundation

struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var matchID: UUID
    var senderID: UUID
    var body: String
    var createdAt: Date
    var readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case senderID = "sender_id"
        case body
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}
