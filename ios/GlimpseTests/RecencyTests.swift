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

    @Test func clipsRotateAfterNinetyDays() {
        #expect(!Recency.isStale(daysAgo(89), now: now))
        #expect(Recency.isStale(daysAgo(90.5), now: now))
    }
}
