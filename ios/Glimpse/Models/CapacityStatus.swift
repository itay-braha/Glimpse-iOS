import Foundation

struct CapacityStatus: Codable, Hashable, Sendable {
    var active: Int
    var cap: Int
    var atCapacity: Bool
    var nextToBoot: NextToBoot?
    var freezesAllowed: Int?

    static let empty = CapacityStatus(active: 0, cap: 20, atCapacity: false, nextToBoot: nil, freezesAllowed: 1)

    enum CodingKeys: String, CodingKey {
        case active
        case cap
        case atCapacity = "at_capacity"
        case nextToBoot = "next_to_boot"
        case freezesAllowed = "freezes_allowed"
    }
}
