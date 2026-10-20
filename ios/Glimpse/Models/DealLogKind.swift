import Foundation

/// Moments in the deal flow the app logs (the server logs opening and redeeming itself).
enum DealLogKind: String, Sendable {
    case viewed
    /// "I'm not at this place."
    case notHere = "not_here"
    /// Picked another place from the list instead.
    case choseOther = "chose_other"
}
