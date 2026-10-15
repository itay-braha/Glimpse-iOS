import Foundation

/// Fields the client is allowed to change (mirrors the column grants in the migration).
struct ProfileUpdate: Codable, Sendable {
    var displayName: String
    var bio: String?
    var city: String?
    var interestedIn: [Gender]
    var ageMin: Int
    var ageMax: Int
    var maxDistanceKm: Int

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case bio
        case city
        case interestedIn = "interested_in"
        case ageMin = "age_min"
        case ageMax = "age_max"
        case maxDistanceKm = "max_distance_km"
    }
}
