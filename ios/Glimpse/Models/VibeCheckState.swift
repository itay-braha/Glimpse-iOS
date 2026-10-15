import Foundation

/// The caller's view of a match's 3-Minute Vibe Check (from `get_vibe_check`).
struct VibeCheckState: Codable, Hashable, Sendable {
    enum Status: String, Codable, Sendable {
        case locked
        case eligible
        /// The key holder gave the green light (named after the spec's woman–man case).
        case femaleUnlocked = "female_unlocked"
        case scheduled
        case completed
        case disabled
    }

    var status: Status
    var iHoldKey: Bool
    var otherHoldsKey: Bool
    var showNudge: Bool
    var unlockedByOther: Bool?
    var scheduledAt: Date?
    var initiatedByMe: Bool?
    var confirmed: Bool
    var canJoin: Bool
    var startedAt: Date?
    var vibeVerified: Bool
    var immunityUntil: Date?
    var criteria: VibeCriteria

    /// The other person proposed a time and is waiting on me.
    var awaitingMyAnswer: Bool {
        status == .scheduled && !confirmed && initiatedByMe == false
    }

    /// I may suggest a time: key holders once eligible, everyone else after a green light.
    var canPropose: Bool {
        if iHoldKey { return [.eligible, .femaleUnlocked].contains(status) }
        return status == .femaleUnlocked && unlockedByOther == true
    }

    enum CodingKeys: String, CodingKey {
        case status
        case iHoldKey = "i_hold_key"
        case otherHoldsKey = "other_holds_key"
        case showNudge = "show_nudge"
        case unlockedByOther = "unlocked_by_other"
        case scheduledAt = "scheduled_at"
        case initiatedByMe = "initiated_by_me"
        case confirmed
        case canJoin = "can_join"
        case startedAt = "started_at"
        case vibeVerified = "vibe_verified"
        case immunityUntil = "immunity_until"
        case criteria
    }
}
