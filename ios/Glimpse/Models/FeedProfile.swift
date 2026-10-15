import Foundation

struct FeedProfile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var age: Int
    var city: String?
    var bio: String?
    var isVerified: Bool?
    /// Approximate distance, rounded to whole kilometres (nil when either side has no location).
    var distanceKm: Int?
    var videos: [ProfileVideo]
    /// Why this card is here when it's outside the viewer's own filters.
    var discoveryNote: DiscoveryNote?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case age
        case city
        case bio
        case isVerified = "is_verified"
        case distanceKm = "distance_km"
        case videos
        case discoveryNote = "discovery_note"
    }
}
