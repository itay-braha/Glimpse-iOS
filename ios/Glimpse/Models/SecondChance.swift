import Foundation

/// Someone asking to reconnect after the 20-cap released them.
struct SecondChance: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var createdAt: Date
    var profile: FeedProfile

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case profile
    }
}
