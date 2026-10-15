import Foundation

enum VibeOutcome: String, Sendable {
    /// "The vibe matched"
    case matched
    /// "Friendly, but no romantic chemistry"
    case friendly
    /// "Report conduct / didn't match their profile"
    case report
}
