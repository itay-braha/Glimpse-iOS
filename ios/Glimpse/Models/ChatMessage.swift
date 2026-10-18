import Foundation

struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var matchID: UUID
    var senderID: UUID
    var body: String
    var createdAt: Date
    var readAt: Date?
    /// The message this one quotes.
    var replyTo: UUID?
    var unsentAt: Date?
    /// Text unless it's a voice message or video note (nil on older rows = text).
    var kind: MessageKind?
    /// The recording, for voice and video messages (cleared when deleted).
    var mediaPath: String?
    var mediaDuration: Double?
    /// Deleted for everyone by the sender (the safety team keeps a copy for 30 days).
    var deletedAt: Date?

    var isUnsent: Bool { unsentAt != nil || deletedAt != nil }
    var resolvedKind: MessageKind { kind ?? .text }

    enum CodingKeys: String, CodingKey {
        case id
        case matchID = "match_id"
        case senderID = "sender_id"
        case body
        case createdAt = "created_at"
        case readAt = "read_at"
        case replyTo = "reply_to"
        case unsentAt = "unsent_at"
        case kind
        case mediaPath = "media_path"
        case mediaDuration = "media_duration"
        case deletedAt = "deleted_at"
    }
}
