import Foundation

/// The live pass staff look at. Valid for 15 minutes; the code changes every day.
struct DealPass: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let expiresAt: Date
    let code: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id, code, name
        case expiresAt = "expires_at"
    }
}
