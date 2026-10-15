import Foundation

/// City waitlist ("velvet rope"): the feed opens once enough members are nearby.
struct DensityStatus: Codable, Hashable, Sendable {
    var unlocked: Bool
    var localMembers: Int
    var required: Int
    var radiusKm: Int

    static let open = DensityStatus(unlocked: true, localMembers: 0, required: 0, radiusKm: 50)

    enum CodingKeys: String, CodingKey {
        case unlocked
        case localMembers = "local_members"
        case required
        case radiusKm = "radius_km"
    }
}
