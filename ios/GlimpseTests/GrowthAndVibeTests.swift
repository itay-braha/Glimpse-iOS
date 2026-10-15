import Foundation
@testable import Glimpse
import Testing

/// Client-visible contract for pause, the daily profile limit, freezes,
/// missed connections and the Vibe Check (the database enforces the same
/// rules; see supabase/tests).
struct GrowthAndVibeTests {
    private let dana = DemoData.id(1_000)

    @Test func freeMembersSeeFiftyNewProfilesADay() async throws {
        let backend = DemoBackend(seeded: true)
        for _ in 0..<50 {
            _ = try await backend.swipe(on: UUID(), liked: false)
        }
        #expect(try await backend.likeQuota().viewsRemaining == 0)
        #expect(try await backend.fetchFeed(limit: 10).isEmpty)
        await #expect(throws: GlimpseError.outOfViews) {
            try await backend.swipe(on: UUID(), liked: false)
        }
        // Answering an admirer never counts against the limit.
        let admirer = try #require(DemoData.admirers().first)
        #expect(try await backend.swipe(on: admirer.id, liked: true).matched)
    }

    @Test func pausedMembersCantSwipeAndSeeNoFeed() async throws {
        let backend = DemoBackend(seeded: true)
        let until = try await backend.setPause(days: 7)
        #expect(until != nil)
        #expect(try await backend.fetchFeed(limit: 10).isEmpty)
        await #expect(throws: GlimpseError.paused) {
            try await backend.swipe(on: UUID(), liked: false)
        }
        _ = try await backend.setPause(days: 0)
        let feed = try await backend.fetchFeed(limit: 10)
        #expect(!feed.isEmpty)
    }

    @Test func aFrozenConnectionIsNeverReleased() async throws {
        let backend = DemoBackend(seeded: true)
        try await backend.setFrozen(dana, frozen: true)
        #expect(try await backend.capacityStatus().nextToBoot?.displayName != "Dana")

        let admirer = try #require(DemoData.admirers().first)
        let result = try await backend.swipe(on: admirer.id, liked: true)
        #expect(result.booted != nil)
        #expect(result.booted?.displayName != "Dana")
        #expect(try await backend.missedConnections().contains { $0.matchID == result.booted?.matchID })
    }

    @Test func freeMembersGetOneFreeze() async throws {
        let backend = DemoBackend(seeded: true)
        let matches = try await backend.fetchMatches()
        try await backend.setFrozen(matches[0].matchID, frozen: true)
        await #expect(throws: GlimpseError.freezeLimit) {
            try await backend.setFrozen(matches[1].matchID, frozen: true)
        }
    }

    @Test func secondChancesNeedGlimpsePlus() async throws {
        let backend = DemoBackend(seeded: true)
        let missed = try #require(try await backend.missedConnections().first)
        await #expect(throws: GlimpseError.plusRequired) {
            try await backend.requestSecondChance(matchID: missed.matchID)
        }
        _ = try await backend.verifyPurchase(signedTransaction: "demo")
        try await backend.requestSecondChance(matchID: missed.matchID)
        #expect(try await backend.missedConnections().first?.secondChanceStatus == "pending")
    }

    @Test func vibeCheckLastsExactlyThreeMinutes() async throws {
        let backend = DemoBackend(seeded: true)
        let matchID = try #require(try await backend.fetchMatches().first?.matchID)
        let clock = try await backend.vibeMarkStarted(matchID: matchID)
        #expect(clock.endsAt.timeIntervalSince(clock.startedAt) == 180)
    }

    @Test func aMutualVibeMatchVerifiesAndProtectsTheConnection() async throws {
        let backend = DemoBackend(seeded: true)
        let matchID = try #require(try await backend.fetchMatches().first?.matchID)
        _ = try await backend.vibeCheck(matchID: matchID)
        #expect(try await backend.vibeSubmitResult(matchID: matchID, outcome: .matched))
        let state = try await backend.vibeCheck(matchID: matchID)
        #expect(state.vibeVerified)
        #expect(state.immunityUntil != nil)
    }

    @Test func onlyTheKeyHolderCanInviteRightAway() {
        let base = VibeCheckState(
            status: .eligible, iHoldKey: false, otherHoldsKey: true, showNudge: false, unlockedByOther: false,
            scheduledAt: nil, initiatedByMe: nil, confirmed: false, canJoin: false, startedAt: nil,
            vibeVerified: false, immunityUntil: nil,
            criteria: VibeCriteria(eligible: true, messages: 24, balanced: true, days: 2, recent: true,
                                   contactRequest: false, flagged: false)
        )
        #expect(!base.canPropose)

        var greenLit = base
        greenLit.status = .femaleUnlocked
        greenLit.unlockedByOther = true
        #expect(greenLit.canPropose)

        var holder = base
        holder.iHoldKey = true
        #expect(holder.canPropose)
    }
}
