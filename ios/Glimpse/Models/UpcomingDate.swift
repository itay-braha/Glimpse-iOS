import Foundation

/// A planned date as shown in the Connections list.
struct UpcomingDate: Codable, Hashable, Sendable {
    let matchID: UUID
    var startsAt: Date
    var status: PlannedDate.Status
    var place: String
    var proposedBy: UUID

    enum CodingKeys: String, CodingKey {
        case status, place
        case matchID = "match_id"
        case startsAt = "starts_at"
        case proposedBy = "proposed_by"
    }
}
