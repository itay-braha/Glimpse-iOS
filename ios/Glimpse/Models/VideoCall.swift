import Foundation

/// One video call between two Vibe Verified matches (up to 15 minutes).
struct VideoCall: Codable, Hashable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable {
        case ringing
        case live
        case declined
        case missed
        case ended
        case cancelled
    }

    let id: UUID
    var status: Status
    let callerID: UUID
    var createdAt: Date?
    var endsAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case callerID = "caller_id"
        case createdAt = "created_at"
        case endsAt = "ends_at"
    }
}
