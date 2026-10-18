import Foundation
@testable import Glimpse
import Testing

/// Freemium rules as the client sees them (the database enforces the same rules; see pgTAP).
struct FreemiumTests {
    @Test func everyoneGetsTenLikesADay() async throws {
        let backend = DemoBackend(seeded: true)
        for _ in 0..<10 {
            _ = try await backend.swipe(on: UUID(), liked: true)
        }
        let quota = try await backend.likeQuota()
        #expect(quota.remaining == 0)
        #expect(quota.resetsAt != nil)
        await #expect(throws: GlimpseError.outOfLikes) {
            try await backend.swipe(on: UUID(), liked: true)
        }
    }

    @Test func likingBackAnAdmirerIsAlwaysFree() async throws {
        let backend = DemoBackend(seeded: true)
        for _ in 0..<10 {
            _ = try await backend.swipe(on: UUID(), liked: true)
        }
        let admirer = try #require(DemoData.admirers().first)
        let result = try await backend.swipe(on: admirer.id, liked: true)
        #expect(result.matched)
    }

    @Test func passesAreNeverLimited() async throws {
        let backend = DemoBackend(seeded: true)
        for _ in 0..<30 {
            _ = try await backend.swipe(on: UUID(), liked: false)
        }
        #expect(try await backend.likeQuota().remaining == 10)
    }

    @Test func likedYouIsFreeForEveryone() async throws {
        let backend = DemoBackend(seeded: true)
        let likes = try await backend.likesReceived()
        #expect(!likes.isPlus)
        #expect(likes.total == DemoData.admirers().count)
        #expect(likes.items.allSatisfy { $0.revealed && $0.profile != nil })
    }

    @Test func outOfLikesPutsAdmirersFirst() async throws {
        let backend = DemoBackend(seeded: true)
        for _ in 0..<10 {
            _ = try await backend.swipe(on: UUID(), liked: true)
        }
        let first = try #require(try await backend.fetchFeed(limit: 10).first)
        #expect(DemoData.likedMe().contains(first.id))
    }

    @Test func plusDoesNotBuyMoreLikes() async throws {
        let backend = DemoBackend(seeded: true)
        #expect(try await backend.verifyPurchase(signedTransaction: "demo"))
        for _ in 0..<10 {
            _ = try await backend.swipe(on: UUID(), liked: true)
        }
        let quota = try await backend.likeQuota()
        #expect(quota.allowance == 10)
        #expect(quota.remaining == 0)
    }
}
