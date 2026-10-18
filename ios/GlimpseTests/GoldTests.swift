import Foundation
@testable import Glimpse
import Testing

/// Glimpse Gold as the client sees it (the database enforces the same rules; see pgTAP).
struct GoldTests {
    private func goldBackend() async throws -> DemoBackend {
        let backend = DemoBackend(seeded: true)
        #expect(try await backend.verifyPurchase(signedTransaction: "demo-gold"))
        return backend
    }

    @Test func goldFeaturesNeedGold() async throws {
        let backend = DemoBackend(seeded: true)
        #expect(try await backend.verifyPurchase(signedTransaction: "demo"))
        await #expect(throws: GlimpseError.goldRequired) { try await backend.startSpotlight() }
        await #expect(throws: GlimpseError.goldRequired) { try await backend.rewindLastPass() }
    }

    @Test func spotlightIsWeekly() async throws {
        let backend = try await goldBackend()
        _ = try await backend.startSpotlight()
        #expect(try await backend.goldStatus().isSpotlightLive)
        await #expect(throws: GlimpseError.spotlightUsed) { try await backend.startSpotlight() }
    }

    @Test func rewindBringsBackTheLastPass() async throws {
        let backend = try await goldBackend()
        let first = try #require(try await backend.fetchFeed(limit: 10).first)
        _ = try await backend.swipe(on: first.id, liked: false)
        #expect(try await backend.rewindLastPass()?.id == first.id)
        #expect(try await backend.fetchFeed(limit: 10).contains { $0.id == first.id })
        #expect(try await backend.goldStatus().rewindsLeft == 4)
    }

    @Test func travelStartsAndEnds() async throws {
        let backend = try await goldBackend()
        _ = try await backend.setTravel(latitude: 31.77, longitude: 35.21, city: "Jerusalem", days: 30)
        let status = try await backend.goldStatus()
        #expect(status.travelCity == "Jerusalem")
        let until = try #require(status.travelUntil)
        #expect(until < Date.now.addingTimeInterval(15 * 86_400))
        try await backend.endTravel()
        #expect(try await backend.goldStatus().isTravelling == false)
    }

    @Test func clipEventsCarryTheClip() throws {
        let event = FeedEvent(target: DemoData.id(7), kind: .clipShown, video: DemoData.id(70))
        let json = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
        #expect(json.contains("\"kind\":\"clip_shown\""))
        #expect(json.contains("\"video\""))
    }
}
