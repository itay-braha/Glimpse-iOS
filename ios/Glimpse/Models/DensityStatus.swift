import Foundation

/// City waitlist ("velvet rope"): the feed opens once enough members are nearby.
struct DensityStatus: Codable, Hashable, Sendable {
    var unlocked: Bool
    var localMembers: Int
    var required: Int
    var radiusKm: Int
    /// The gate is on but we can't place this member yet: ask for their location.
    var needsLocation = false

    static let open = DensityStatus(unlocked: true, localMembers: 0, required: 0, radiusKm: 20)

    init(unlocked: Bool, localMembers: Int, required: Int, radiusKm: Int, needsLocation: Bool = false) {
        self.unlocked = unlocked
        self.localMembers = localMembers
        self.required = required
        self.radiusKm = radiusKm
        self.needsLocation = needsLocation
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unlocked = try container.decode(Bool.self, forKey: .unlocked)
        localMembers = try container.decode(Int.self, forKey: .localMembers)
        required = try container.decode(Int.self, forKey: .required)
        radiusKm = try container.decode(Int.self, forKey: .radiusKm)
        needsLocation = try container.decodeIfPresent(Bool.self, forKey: .needsLocation) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case unlocked
        case localMembers = "local_members"
        case required
        case radiusKm = "radius_km"
        case needsLocation = "needs_location"
    }
}
