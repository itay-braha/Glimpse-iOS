import Foundation

struct MatchSummary: Codable, Identifiable, Hashable, Sendable {
    let matchID: UUID
    var otherUserID: UUID
    var displayName: String
    var age: Int
    var city: String?
    var thumbnailPath: String?
    var createdAt: Date
    var lastMessageAt: Date?
    var messageCount: Int
    var lastMessageBody: String?
    var lastMessageMine: Bool?
    var unreadCount: Int
    /// 1 = the connection the auto-boot engine would release next.
    /// Nil when the connection is frozen (protected from auto-boot).
    var bootRank: Int?
    var isFrozen: Bool?
    /// Set when the other person is on a break (vacation mode).
    var otherPausedUntil: Date?
    var vibeCheckStatus: String?
    var vibeVerified: Bool?

    var id: UUID { matchID }
    var lastActivity: Date { lastMessageAt ?? createdAt }

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case otherUserID = "other_user_id"
        case displayName = "display_name"
        case age
        case city
        case thumbnailPath = "thumbnail_path"
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
        case messageCount = "message_count"
        case lastMessageBody = "last_message_body"
        case lastMessageMine = "last_message_mine"
        case unreadCount = "unread_count"
        case bootRank = "boot_rank"
        case isFrozen = "is_frozen"
        case otherPausedUntil = "other_paused_until"
        case vibeCheckStatus = "vibe_check_status"
        case vibeVerified = "vibe_verified"
    }
}
