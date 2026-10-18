import Foundation

/// What a chat message carries.
enum MessageKind: String, Codable, Sendable {
    case text
    /// A voice message recorded in the chat (up to 2 minutes).
    case voice
    /// A round selfie video note recorded in the chat (up to 60 seconds).
    case video

    /// Recording cap, matching the database's limits.
    var maxDuration: Double {
        switch self {
        case .text: 0
        case .voice: 120
        case .video: 60
        }
    }

    /// Recordings shorter than this are treated as an accidental tap.
    static let minDuration: Double = 0.8
}
