import Foundation

/// Server-anchored call clock.
struct VibeClock: Codable, Hashable, Sendable {
    var startedAt: Date
    var endsAt: Date
    var serverNow: Date

    enum CodingKeys: String, CodingKey {
        case startedAt = "started_at"
        case endsAt = "ends_at"
        case serverNow = "server_now"
    }
}
