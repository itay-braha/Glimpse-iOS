import Foundation
@testable import Glimpse
import Testing

struct RecencyTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func daysAgo(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 86_400)
    }

    @Test(arguments: [
        (0.2, "Added today"),
        (1.5, "Added yesterday"),
        (3.2, "Added 3 days ago"),
        (21, "Added 3 weeks ago"),
        (95, "Added 3 months ago"),
    ])
    func labels(days: Double, expected: String) {
        #expect(Recency.label(daysAgo(days), now: now) == expected)
    }

    @Test func clipsGetARefreshNudgeAfterAYear() {
        #expect(!Recency.isStale(daysAgo(300), now: now))
        #expect(Recency.isStale(daysAgo(366), now: now))
    }

    @Test func onlyClipsFromTheLastYearCanBeAdded() {
        #expect(!Recency.isTooOldToAdd(daysAgo(200), now: now))
        #expect(Recency.isTooOldToAdd(daysAgo(400), now: now))
    }

    @Test func tagsSayHowTheClipWasMade() {
        #expect(Recency.label(daysAgo(3.2), now: now, verb: "Filmed") == "Filmed 3 days ago")
        #expect(Recency.label(daysAgo(95), now: now, verb: "Posted") == "Posted 3 months ago")
    }
}
