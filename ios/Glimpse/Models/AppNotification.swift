import Foundation

struct AppNotification: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case newMatch = "new_match"
        case newMessage = "new_message"
        case connectionEnded = "connection_ended"
        case likedYou = "liked_you"
        case replyNudge = "reply_nudge"
        case moderation
        case verification
        case secondChance = "second_chance"
        case vibeCheck = "vibe_check"
        /// A linked Instagram/TikTok post was deleted or expired and is hidden.
        case videoUnavailable = "video_unavailable"
        /// A kind this build doesn't know yet; never breaks the whole list.
        case other

        init(from decoder: any Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .other
        }
    }

    let id: UUID
    var kind: Kind
    var title: String
    var body: String
    var data: [String: String]?
    var createdAt: Date
    var readAt: Date?

    var matchID: UUID? { data?["match_id"].flatMap(UUID.init(uuidString:)) }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case body
        case data
        case createdAt = "created_at"
        case readAt = "read_at"
    }
}
