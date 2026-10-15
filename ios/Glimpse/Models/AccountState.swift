import Foundation

struct AccountState: Codable, Hashable, Sendable {
    var status: String
    var reason: String?
    var pausedUntil: Date?
    var isPlus: Bool?

    var needsSyntheticMediaVerification: Bool {
        status == "suspended" && reason == "synthetic_media_review"
    }

    enum CodingKeys: String, CodingKey {
        case status
        case reason
        case pausedUntil = "paused_until"
        case isPlus = "is_plus"
    }
}
