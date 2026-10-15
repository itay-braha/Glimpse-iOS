import Foundation

/// A random gesture the user performs in a short selfie video for review.
struct VerificationChallenge: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var gesture: String
}
