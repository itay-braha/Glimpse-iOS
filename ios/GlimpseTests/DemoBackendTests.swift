import Foundation
@testable import Glimpse
import Testing

/// The demo backend mirrors the server's match rules; these tests pin the
/// client-visible contract (the database rules are covered by pgTAP).
struct DemoBackendTests {
    @Test func seededUserStartsAtCapacity() async throws {
        let backend = DemoBackend(seeded: true)
        let status = try await backend.capacityStatus()
        #expect(status.active == DemoBackend.cap)
        #expect(DemoBackend.cap == 15)
        #expect(status.atCapacity)
        #expect(status.nextToBoot?.displayName == "Dana")
    }

    @Test func sixteenthMatchBootsTheStalestConnection() async throws {
        let backend = DemoBackend(seeded: true)
        let feed = try await backend.fetchFeed(limit: 10)
        let admirer = try #require(feed.first)

        let result = try await backend.swipe(on: admirer.id, liked: true)

        #expect(result.matched)
        #expect(result.booted?.displayName == "Dana")
        let matches = try await backend.fetchMatches()
        #expect(matches.count == 15)
        #expect(!matches.contains { $0.displayName == "Dana" })
        #expect(matches.contains { $0.otherUserID == admirer.id })
    }

    @Test func oneSidedLikesDoNotMatch() async throws {
        let backend = DemoBackend(seeded: true)
        let feed = try await backend.fetchFeed(limit: 10)
        let result = try await backend.swipe(on: feed[1].id, liked: true)
        #expect(!result.matched)
        #expect(try await backend.fetchMatches().count == 15)
    }

    @Test func pinsArePersonalAndCappedAtThree() async throws {
        let backend = DemoBackend(seeded: true)
        let matches = try await backend.fetchMatches()
        for match in matches.prefix(3) {
            try await backend.setPinned(match.matchID, pinned: true)
        }
        await #expect(throws: GlimpseError.pinLimit) {
            try await backend.setPinned(matches[3].matchID, pinned: true)
        }
        try await backend.setPinned(matches[0].matchID, pinned: false)
        try await backend.setPinned(matches[3].matchID, pinned: true)
        #expect(try await backend.pinnedMatchIDs() == Set([matches[1], matches[2], matches[3]].map(\.matchID)))
    }

    @Test func swipedProfilesLeaveTheFeed() async throws {
        let backend = DemoBackend(seeded: true)
        let first = try #require(try await backend.fetchFeed(limit: 10).first)
        _ = try await backend.swipe(on: first.id, liked: false)
        let remaining = try await backend.fetchFeed(limit: 10)
        #expect(!remaining.contains { $0.id == first.id })
    }

    @Test func otpRequiresTheDemoCode() async throws {
        let backend = DemoBackend(seeded: false)
        await #expect(throws: GlimpseError.invalidCode) {
            try await backend.verifyCode("000000", phone: "+15555550100")
        }
        let id = try await backend.verifyCode(DemoBackend.demoCode, phone: "+15555550100")
        #expect(id == DemoData.meID)
    }
}
