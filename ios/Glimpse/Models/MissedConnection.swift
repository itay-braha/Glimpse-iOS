import Foundation

/// A connection auto-released by the 20-cap (kept for 30 days).
struct MissedConnection: Codable, Identifiable, Hashable, Sendable {
    let matchID: UUID
    var userID: UUID
    var displayName: String
    var age: Int
    var thumbnailPath: String?
    var endedAt: Date
    /// nil (none sent), "pending", "accepted" or "declined".
    var secondChanceStatus: String?

    var id: UUID { matchID }

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case userID = "user_id"
        case displayName = "display_name"
        case age
        case thumbnailPath = "thumbnail_path"
        case endedAt = "ended_at"
        case secondChanceStatus = "second_chance_status"
    }
}
