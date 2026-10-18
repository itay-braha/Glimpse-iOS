import Foundation

/// The date idea both people see after a good Vibe Check or a long video call:
/// a partner spot near the middle of them, or a general idea when none is near.
struct DateIdea: Codable, Hashable, Identifiable, Sendable {
    enum Feedback: String, Sendable {
        case openMaps = "open_maps"
        case shared
        case went
        case notForUs = "not_for_us"
    }

    let id: UUID
    var createdAt: Date?
    var idea: String?
    var spot: DateSpot?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case idea
        case spot
    }
}
