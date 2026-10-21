import Foundation

struct AccountState: Codable, Hashable, Sendable {
    var status: String
    var reason: String?
    var pausedUntil: Date?
    var isPlus: Bool?
    /// False until a person on the team approves the member's selfie check (nil = not asked).
    var selfieCleared: Bool?

    var needsSyntheticMediaVerification: Bool {
        status == "suspended" && reason == "synthetic_media_review"
    }

    enum CodingKeys: String, CodingKey {
        case status
        case reason
        case pausedUntil = "paused_until"
        case isPlus = "is_plus"
        case selfieCleared = "selfie_cleared"
    }
}
