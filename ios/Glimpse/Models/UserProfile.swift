import Foundation

struct UserProfile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    /// ISO date (yyyy-MM-dd) exactly as Postgres stores it.
    var birthdate: String
    var gender: Gender
    var interestedIn: [Gender]
    var bio: String?
    var city: String?
    var ageMin: Int
    var ageMax: Int
    var isOnboarded: Bool
    var maxDistanceKm: Int?
    var isVerified: Bool?
    var verificationStatus: String?

    var age: Int? {
        guard let date = BirthdateFormat.date(from: birthdate) else { return nil }
        return Calendar.current.dateComponents([.year], from: date, to: .now).year
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case birthdate
        case gender
        case interestedIn = "interested_in"
        case bio
        case city
        case ageMin = "age_min"
        case ageMax = "age_max"
        case isOnboarded = "is_onboarded"
        case maxDistanceKm = "max_distance_km"
        case isVerified = "is_verified"
        case verificationStatus = "verification_status"
    }
}
