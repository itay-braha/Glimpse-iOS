import Foundation

/// A partner place's offer for Glimpse members ("10% off two coffees").
struct Deal: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let spotID: UUID
    var place: String
    var category: DateSpot.Category?
    var address: String?
    let latitude: Double
    let longitude: Double
    var mapsURL: String?
    var title: String
    var details: String?
    var terms: String?
    var state: DealState
    var availableAgainAt: Date?
    /// Only sent when it's nearly gone ("Only 6 left").
    var remaining: Int?
    /// From my approximate location.
    var distanceKm: Double?

    var distanceLabel: String? {
        guard let km = distanceKm else { return nil }
        if km < 1 { return String(localized: "\(Int((km * 1_000 / 50).rounded() * 50)) m away") }
        return String(localized: "\(km.formatted(.number.precision(.fractionLength(1)))) km away")
    }

    enum CodingKeys: String, CodingKey {
        case id, place, category, address, latitude, longitude, title, details, terms, state, remaining
        case spotID = "spot_id"
        case mapsURL = "maps_url"
        case availableAgainAt = "available_again_at"
        case distanceKm = "distance_km"
    }
}
