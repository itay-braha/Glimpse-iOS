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
    /// Show people slightly outside the filters once everyone inside has been seen.
    var flexibleDiscovery: Bool?
    /// What buzzes the phone (all / messages / none).
    var pushScope: PushScope?
    /// Alerts added on top of "Just messages" (e.g. Vibe Check reminders).
    var pushExtras: [AlertExtra]?
    /// Opt-in: pseudonymous activity may train Glimpse's matching and safety models.
    var consentAiTraining: Bool?
    /// Opt-in: aggregate statistics (groups of 20+) may be shared outside Glimpse.
    var consentDataSharing: Bool?

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
        case flexibleDiscovery = "flexible_discovery"
        case pushScope = "push_scope"
        case pushExtras = "push_extras"
        case consentAiTraining = "consent_ai_training"
        case consentDataSharing = "consent_data_sharing"
    }
}
