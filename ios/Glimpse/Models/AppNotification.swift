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
