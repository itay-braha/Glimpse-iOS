import Foundation
@testable import Glimpse
import Testing

/// In-context alert offers are rare and polite: these pin the pacing rules.
struct AlertNudgeTests {
    private func fresh() -> AlertNudges {
        let name = "nudges-\(UUID().uuidString)"
        return AlertNudges(defaults: UserDefaults(suiteName: name)!)
    }

    private let start = Date(timeIntervalSince1970: 1_800_000_000)
    private func days(_ n: Double) -> Date { start.addingTimeInterval(n * 86_400) }

    @Test func quietRightAfterTheFirstChoice() {
        let nudges = fresh()
        nudges.recordFirstChoice(now: start)
        #expect(!nudges.mayAsk(.vibeCheck, now: days(1)))
        #expect(nudges.mayAsk(.vibeCheck, now: days(3)))
    }

    @Test func oneOfferEveryTenDaysAcrossTopics() {
        let nudges = fresh()
        nudges.recordAsked(.vibeCheck, now: start)
        nudges.recordAnswer(.vibeCheck, accepted: true, never: false, now: start)
        #expect(!nudges.mayAsk(.newMatch, now: days(5)))
        #expect(nudges.mayAsk(.newMatch, now: days(11)))
    }

    @Test func notNowWaitsAMonthAndTwiceIsTheMost() {
        let nudges = fresh()
        nudges.recordAsked(.vibeCheck, now: start)
        nudges.recordAnswer(.vibeCheck, accepted: false, never: false, now: start)
        #expect(!nudges.mayAsk(.vibeCheck, now: days(20)))
        #expect(nudges.mayAsk(.vibeCheck, now: days(31)))
        nudges.recordAsked(.vibeCheck, now: days(31))
        nudges.recordAnswer(.vibeCheck, accepted: false, never: false, now: days(31))
        #expect(!nudges.mayAsk(.vibeCheck, now: days(400)))
    }

    @Test func dontAskAgainIsForever() {
        let nudges = fresh()
        nudges.recordAsked(.replies, now: start)
        nudges.recordAnswer(.replies, accepted: false, never: true, now: start)
        #expect(!nudges.mayAsk(.replies, now: days(1_000)))
        #expect(nudges.mayAsk(.vibeCheck, now: days(11)))
    }

    @Test func extrasAreSaved() async throws {
        let backend = DemoBackend(seeded: true)
        try await backend.setPushScope(.messages)
        try await backend.setPushExtras([.vibeCheck])
        let profile = try #require(try await backend.fetchMyProfile())
        #expect(profile.pushScope == .messages)
        #expect(profile.pushExtras == [.vibeCheck])
    }
}
