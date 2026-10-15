import Foundation
@testable import Glimpse
import Testing

struct StalenessTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func match(_ name: String, quietDays: Double, messages: Int, ageDays: Double = 30) -> MatchSummary {
        MatchSummary(
            matchID: UUID(),
            otherUserID: UUID(),
            displayName: name,
            age: 25,
            city: nil,
            thumbnailPath: nil,
            createdAt: now.addingTimeInterval(-ageDays * 86_400),
            lastMessageAt: now.addingTimeInterval(-quietDays * 86_400),
            messageCount: messages,
            lastMessageBody: nil,
            lastMessageMine: nil,
            unreadCount: 0,
            bootRank: 0
        )
    }

    @Test func silentMatchesAreStalerThanBusyOnes() {
        let silent = Staleness.score(lastActivity: now.addingTimeInterval(-10 * 86_400), messageCount: 0, now: now)
        let busy = Staleness.score(lastActivity: now.addingTimeInterval(-10 * 86_400), messageCount: 40, now: now)
        #expect(silent > busy * 4)
    }

    @Test func freshMatchesAreProtected() {
        let brandNew = Staleness.score(lastActivity: now.addingTimeInterval(-3600), messageCount: 0, now: now)
        let dormant = Staleness.score(lastActivity: now.addingTimeInterval(-7 * 86_400), messageCount: 20, now: now)
        #expect(brandNew < dormant)
    }

    @Test func rankPutsTheStalestFirst() {
        let ranked = Staleness.rank([
            match("Active", quietDays: 0.1, messages: 30),
            match("Ghost", quietDays: 19, messages: 1),
            match("Slow", quietDays: 4, messages: 8),
        ], now: now)
        #expect(ranked.map(\.displayName) == ["Ghost", "Slow", "Active"])
    }
}
