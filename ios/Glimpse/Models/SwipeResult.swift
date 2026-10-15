import Foundation

struct SwipeResult: Codable, Hashable, Sendable {
    var matched: Bool
    var matchID: UUID?
    /// Present when approving this match auto-released the caller's stalest connection.
    var booted: BootedConnection?
    var likesRemaining: Int?

    enum CodingKeys: String, CodingKey {
        case matched
        case matchID = "match_id"
        case booted
        case likesRemaining = "likes_remaining"
    }
}
