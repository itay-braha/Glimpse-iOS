import Foundation

/// Which alerts someone wants on their phone. Everything still shows in the
/// app's activity list; this only decides what buzzes.
enum PushScope: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Matches, likes, messages, Vibe Check calls and reminders.
    case all
    /// Only new messages and reactions from matches.
    case messages
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "Everything")
        case .messages: String(localized: "Just messages")
        case .none: String(localized: "Nothing")
        }
    }

    var detail: String {
        switch self {
        case .all: String(localized: "New matches, who liked you, messages, Vibe Check invites and reminders.")
        case .messages: String(localized: "Only when a match texts you or reacts to your message.")
        case .none: String(localized: "No alerts. You'll see everything when you open Glimpse.")
        }
    }
}
