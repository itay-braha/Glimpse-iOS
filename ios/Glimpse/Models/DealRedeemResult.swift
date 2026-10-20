import Foundation

/// What happened when staff tapped Redeem.
struct DealRedeemResult: Codable, Hashable, Sendable {
    enum Status: String, Codable, Sendable {
        case redeemed, expired, used, ended
        case soldOut = "sold_out"
        case available
    }

    let status: Status
    var redeemedAt: Date?

    enum CodingKeys: String, CodingKey {
        case status
        case redeemedAt = "redeemed_at"
    }
}
