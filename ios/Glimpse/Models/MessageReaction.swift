import Foundation

/// One person's emoji on one message (one per person; nil = removed).
struct MessageReaction: Codable, Hashable, Sendable {
    /// The six reactions, in the order the picker shows them.
    static let palette = ["❤️", "😂", "😮", "😢", "🔥", "👍"]

    let messageID: UUID
    let userID: UUID
    var matchID: UUID?
    var emoji: String?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case userID = "user_id"
        case matchID = "match_id"
        case emoji
    }
}
