import Foundation
@testable import Glimpse
import Testing

/// Video calls after a good Vibe Check, as the client sees them (the database
/// enforces the same rules; see pgTAP).
struct VideoCallTests {
    @Test func offUntilAGoodVibeCheck() async throws {
        let backend = DemoBackend(seeded: true)
        let match = try #require(try await backend.fetchMatches().first)
        let state = try await backend.videoCallState(matchID: match.matchID)
        #expect(!state.available)
        #expect(state.reason == .needsVibeCheck)
        #expect(!state.isRelevant)
    }

    @Test func ringAnswerAndFifteenMinutes() async throws {
        let backend = DemoBackend(seeded: true, videoCalls: true)
        let match = try #require(try await backend.fetchMatches().first)
        let id = try await backend.ringVideoCall(matchID: match.matchID)
        #expect(try await backend.videoCallState(matchID: match.matchID).activeCall?.id == id)
        await #expect(throws: GlimpseError.ringLimit) {
            try await backend.ringVideoCall(matchID: match.matchID)
        }
        try await Task.sleep(for: .seconds(2))
        let clock = try await backend.videoCallClock(callID: id)
        #expect(abs(clock.endsAt.timeIntervalSince(clock.startedAt) - 15 * 60) < 1)
    }

    @Test func blockingEndsTheCallAndTurnsCallsOff() async throws {
        let backend = DemoBackend(seeded: true, videoCalls: true)
        let match = try #require(try await backend.fetchMatches().first)
        _ = try await backend.ringVideoCall(matchID: match.matchID)
        try await backend.blockMatchVideoCalls(matchID: match.matchID, blocked: true)
        let state = try await backend.videoCallState(matchID: match.matchID)
        #expect(state.reason == .blocked)
        #expect(state.activeCall == nil)
        #expect(state.blockedByMe)
    }

    @Test func serverStateDecodes() throws {
        let json = """
        {"available": false, "reason": "not_enabled", "i_hold_key": true, "my_global_enabled": false,
         "i_allowed": false, "blocked_by_me": false, "recording_agreed": false, "calls_today": 0,
         "calls_per_day": 4, "ring_available_at": null, "can_ring": false, "active_call": null}
        """
        let state = try JSONDecoder.glimpse().decode(VideoCallState.self, from: Data(json.utf8))
        #expect(state.reason == .notEnabled)
        #expect(state.iHoldKey)
        #expect(state.isRelevant)
    }
}
