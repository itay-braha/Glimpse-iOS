import Foundation

/// Freemium like allowance (rolling 24 hours). Liking back an admirer never uses it.
struct LikeQuota: Codable, Hashable, Sendable {
    var allowance: Int
    var remaining: Int
    var resetsAt: Date?
    var isPlus: Bool
    /// Daily limit on new profiles seen (likes + passes).
    var viewsAllowance: Int?
    var viewsRemaining: Int?
    var viewsResetAt: Date?

    enum CodingKeys: String, CodingKey {
        case allowance
        case remaining
        case resetsAt = "resets_at"
        case isPlus = "is_plus"
        case viewsAllowance = "views_allowance"
        case viewsRemaining = "views_remaining"
        case viewsResetAt = "views_reset_at"
    }
}
