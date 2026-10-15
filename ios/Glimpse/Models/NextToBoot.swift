import Foundation

struct NextToBoot: Codable, Hashable, Sendable {
    var matchID: UUID
    var userID: UUID
    var displayName: String
    var lastActivityAt: Date
    var messageCount: Int

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case userID = "user_id"
        case displayName = "display_name"
        case lastActivityAt = "last_activity_at"
        case messageCount = "message_count"
    }
}
