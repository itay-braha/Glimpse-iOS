import Foundation

/// Whether a coffee deal can be used right now, for me.
enum DealState: String, Codable, Sendable {
    case available
    /// The place gave away everything it agreed to ("the first 50").
    case soldOut = "sold_out"
    /// I used it recently; it comes back after a few days.
    case used
    case ended
}
