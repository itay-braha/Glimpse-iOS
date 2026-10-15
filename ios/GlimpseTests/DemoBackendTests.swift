import Foundation
@testable import Glimpse
import Testing

/// The demo backend mirrors the server's match rules; these tests pin the
/// client-visible contract (the database rules are covered by pgTAP).
struct DemoBackendTests {
    @Test func seededUserStartsAtCapacity() async throws {
        let backend = DemoBackend(seeded: true)
        let status = try await backend.capacityStatus()
        #expect(status.active == 20)
        #expect(status.atCapacity)
        #expect(status.nextToBoot?.displayName == "Dana")
    }

    @Test func twentyFirstMatchBootsTheStalestConnection() async throws {
        let backend = DemoBackend(seeded: true)
        let feed = try await backend.fetchFeed(limit: 10)
        let admirer = try #require(feed.first)

        let result = try await backend.swipe(on: admirer.id, liked: true)

        #expect(result.matched)
        #expect(result.booted?.displayName == "Dana")
        let matches = try await backend.fetchMatches()
        #expect(matches.count == 20)
        #expect(!matches.contains { $0.displayName == "Dana" })
        #expect(matches.contains { $0.otherUserID == admirer.id })
    }

    @Test func oneSidedLikesDoNotMatch() async throws {
        let backend = DemoBackend(seeded: true)
        let feed = try await backend.fetchFeed(limit: 10)
        let result = try await backend.swipe(on: feed[1].id, liked: true)
        #expect(!result.matched)
        #expect(try await backend.fetchMatches().count == 20)
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
