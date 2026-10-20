import Foundation

/// Why a kind goodbye is being offered in this chat.
enum GoodbyeTrigger: String, Codable, Sendable {
    /// I said "friendly, no romantic chemistry" after a Vibe Check.
    case vibeNoSpark = "vibe_no_spark"
    /// They wrote last, days ago, and I haven't answered.
    case stoppedReplying = "stopped_replying"
    /// I'm unmatching and they wrote last.
    case unmatchAfterTheirMessage = "unmatch_after_their_message"
}
