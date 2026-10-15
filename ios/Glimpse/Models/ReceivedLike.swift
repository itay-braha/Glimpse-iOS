import Foundation

/// A revealed like carries the full profile; a hidden one only a teaser.
struct ReceivedLike: Codable, Hashable, Identifiable, Sendable {
    var revealed: Bool
    var likedAt: Date
    var age: Int?
    var distanceKm: Int?
    var isVerified: Bool?
    var profile: FeedProfile?

    /// Hidden likes carry no user id (that's the point), so their identity is the like itself.
    var id: String {
        profile.map { "user-\($0.id.uuidString)" } ?? "hidden-\(likedAt.timeIntervalSince1970)-\(age ?? 0)"
    }

    enum CodingKeys: String, CodingKey {
        case revealed
        case likedAt = "liked_at"
        case age
        case distanceKm = "distance_km"
        case isVerified = "is_verified"
        case profile
    }
}
