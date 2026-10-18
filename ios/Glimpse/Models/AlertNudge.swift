import Foundation

/// A one-off, in-context offer to turn on one kind of alert, shown only when
/// it's relevant right now (see `AlertNudges` for how rarely).
struct AlertNudge: Identifiable, Hashable, Sendable {
    enum Topic: String, Sendable {
        /// Someone on "Just messages" just scheduled or accepted a Vibe Check.
        case vibeCheck = "vibe_check"
        /// Someone on "Just messages" just matched.
        case newMatch = "new_match"
        /// Alerts are off entirely and they just sent a message.
        case replies
    }

    let topic: Topic
    /// The other person, for a warmer line ("when Dana replies").
    let name: String

    var id: String { topic.rawValue }

    /// The alert kind it adds on top of "Just messages" (nil: it's about turning alerts on at all).
    var extra: AlertExtra? {
        switch topic {
        case .vibeCheck: .vibeCheck
        case .newMatch: .newMatch
        case .replies: nil
        }
    }

    var symbol: String {
        switch topic {
        case .vibeCheck: "video.badge.waveform.fill"
        case .newMatch: "heart.circle.fill"
        case .replies: "bubble.left.and.text.bubble.right.fill"
        }
    }

    var title: String {
        switch topic {
        case .vibeCheck: "A heads-up before your Vibe Check?"
        case .newMatch: "Want to know about new matches?"
        case .replies: "Want to know when \(name) replies?"
        }
    }

    var message: String {
        switch topic {
        case .vibeCheck:
            "You're on \"Just messages\", so we'd stay quiet. We can also tap you on the shoulder a few minutes before your call with \(name), and when they're in the lobby. Nothing else changes."
        case .newMatch:
            "You're on \"Just messages\". We can also let you know the moment someone likes you back, like \(name) just did. Nothing else changes."
        case .replies:
            "Alerts are off, so you'd only see it next time you open Glimpse. We can let you know when a match writes back. Just messages, nothing else."
        }
    }
}
