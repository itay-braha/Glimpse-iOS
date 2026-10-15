import Foundation

/// Progress toward eligibility (shown as gentle hints, never as a score).
struct VibeCriteria: Codable, Hashable, Sendable {
    var eligible: Bool
    var messages: Int
    var balanced: Bool
    var days: Int
    var recent: Bool
    var contactRequest: Bool
    var flagged: Bool

    enum CodingKeys: String, CodingKey {
        case eligible
        case messages
        case balanced
        case days
        case recent
        case contactRequest = "contact_request"
        case flagged
    }
}
