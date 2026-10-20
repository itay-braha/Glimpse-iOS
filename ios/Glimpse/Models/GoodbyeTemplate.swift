import Foundation

/// Ready-made kind goodbyes. Each is a starting point the sender can edit.
enum GoodbyeTemplate: String, CaseIterable, Identifiable, Sendable {
    case warm
    case honest
    case afterVibeCheck = "after_vibe_check"
    case slowReply = "slow_reply"

    var id: String { rawValue }

    /// The three that fit this moment, the most fitting first.
    static func choices(for trigger: GoodbyeTrigger) -> [GoodbyeTemplate] {
        switch trigger {
        case .vibeNoSpark: [.afterVibeCheck, .warm, .honest]
        case .stoppedReplying: [.slowReply, .warm, .honest]
        case .unmatchAfterTheirMessage: [.warm, .honest, .slowReply]
        }
    }

    var title: String {
        switch self {
        case .warm: String(localized: "Warm")
        case .honest: String(localized: "Short and honest")
        case .afterVibeCheck: String(localized: "After the Vibe Check")
        case .slowReply: String(localized: "Sorry for the silence")
        }
    }

    func text(to name: String) -> String {
        switch self {
        case .warm:
            String(localized: "I really enjoyed getting to know you, \(name), but I don't think we're the right match. Wishing you all the best!")
        case .honest:
            String(localized: "Hey \(name), I don't feel we're a match, and I'd rather tell you than just disappear. Take care!")
        case .afterVibeCheck:
            String(localized: "Thanks for the Vibe Check, \(name)! It was really nice, but I didn't feel a romantic spark. Good luck out there.")
        case .slowReply:
            String(localized: "Sorry it took me a while, \(name). I don't think we're a match, but it was lovely chatting. All the best!")
        }
    }
}
