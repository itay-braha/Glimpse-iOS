import Foundation

/// Glimpse Gold perks as they stand right now (mirrors `gold_status`).
struct GoldStatus: Codable, Hashable, Sendable {
    var isGold: Bool
    /// Set while a Spotlight is running.
    var spotlightUntil: Date?
    /// Set while the weekly Spotlight is used up.
    var spotlightAvailableAt: Date?
    var rewindsLeft: Int
    var travelCity: String?
    var travelUntil: Date?

    static let none = GoldStatus(isGold: false, spotlightUntil: nil, spotlightAvailableAt: nil, rewindsLeft: 0)

    var isSpotlightLive: Bool { (spotlightUntil ?? .distantPast) > .now }
    var canStartSpotlight: Bool { isGold && !isSpotlightLive && (spotlightAvailableAt ?? .distantPast) <= .now }
    var isTravelling: Bool { travelCity != nil && (travelUntil ?? .distantPast) > .now }

    enum CodingKeys: String, CodingKey {
        case isGold = "is_gold"
        case spotlightUntil = "spotlight_until"
        case spotlightAvailableAt = "spotlight_available_at"
        case rewindsLeft = "rewinds_left"
        case travelCity = "travel_city"
        case travelUntil = "travel_until"
    }
}
