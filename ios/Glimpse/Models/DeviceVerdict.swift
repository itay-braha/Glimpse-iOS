import Foundation

struct DeviceVerdict: Codable, Hashable, Sendable {
    var allowed: Bool
    var verified: Bool?
    var reason: String?
}
