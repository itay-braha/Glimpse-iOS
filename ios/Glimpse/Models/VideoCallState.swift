import Foundation

/// Video calls in one match, from my side (mirrors `get_video_calls`).
struct VideoCallState: Codable, Hashable, Sendable {
    /// Why calls aren't available, when they aren't.
    enum Reason: String, Codable, Sendable {
        case noMatch = "no_match"
        case needsVibeCheck = "needs_vibe_check"
        case unavailable
        case blocked
        case notEnabled = "not_enabled"
        case notAllowed = "not_allowed"
    }

    var available: Bool
    var reason: Reason?
    /// In a woman–man match only she does; otherwise both.
    var iHoldKey: Bool
    var myGlobalEnabled: Bool
    var iAllowed: Bool
    var blockedByMe: Bool
    var recordingAgreed: Bool
    var callsToday: Int
    var callsPerDay: Int
    var ringAvailableAt: Date?
    var canRing: Bool
    var activeCall: VideoCall?

    static let off = VideoCallState(
        available: false, reason: .needsVibeCheck, iHoldKey: false, myGlobalEnabled: false, iAllowed: false,
        blockedByMe: false, recordingAgreed: false, callsToday: 0, callsPerDay: 4, canRing: false
    )

    /// Shown in the chat at all: only once a Vibe Check went well, and not while unavailable for safety reasons.
    var isRelevant: Bool { reason != .needsVibeCheck && reason != .noMatch && reason != .unavailable }

    enum CodingKeys: String, CodingKey {
        case available
        case reason
        case iHoldKey = "i_hold_key"
        case myGlobalEnabled = "my_global_enabled"
        case iAllowed = "i_allowed"
        case blockedByMe = "blocked_by_me"
        case recordingAgreed = "recording_agreed"
        case callsToday = "calls_today"
        case callsPerDay = "calls_per_day"
        case ringAvailableAt = "ring_available_at"
        case canRing = "can_ring"
        case activeCall = "active_call"
    }
}
