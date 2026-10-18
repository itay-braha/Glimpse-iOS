import Foundation

/// A first date the two of them are planning (or had), at a date-idea spot.
struct PlannedDate: Codable, Hashable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable {
        case proposed, confirmed, declined, cancelled
    }

    let id: UUID
    let matchID: UUID
    var place: String
    var startsAt: Date
    var status: Status
    var proposedBy: UUID
    var latitude: Double?
    var longitude: Double?
    var mapsURL: String?
    var address: String?
    /// What I said about it afterwards (private).
    var myCheckin: DateOutcome?
    var canCheckIn: Bool

    var isUpcoming: Bool { (status == .proposed || status == .confirmed) && startsAt > .now.addingTimeInterval(-3 * 3600) }

    var mapsLink: URL? {
        if let mapsURL, let url = URL(string: mapsURL) { return url }
        // A general idea has no place to find; a venue gets a Google Maps search
        // (opens the Google Maps app when installed).
        guard latitude != nil else { return nil }
        var parts = URLComponents(string: "https://www.google.com/maps/search/")
        let query = "\(place) \(address ?? "")"
        parts?.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: query)]
        return parts?.url
    }

    enum CodingKeys: String, CodingKey {
        case id, place, status, latitude, longitude, address
        case matchID = "match_id"
        case startsAt = "starts_at"
        case proposedBy = "proposed_by"
        case mapsURL = "maps_url"
        case myCheckin = "my_checkin"
        case canCheckIn = "can_check_in"
    }
}
