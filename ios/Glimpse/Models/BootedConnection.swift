import Foundation

struct BootedConnection: Codable, Hashable, Sendable {
    var matchID: UUID
    var userID: UUID
    var displayName: String

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case userID = "user_id"
        case displayName = "display_name"
    }
}
