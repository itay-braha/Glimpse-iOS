import Foundation
@testable import Glimpse
import Testing

/// Date ideas and Vibe Check topics as the client sees them (the database
/// enforces the same rules; see pgTAP).
struct DateIdeaTests {
    @Test func noDateIdeaBeforeAGoodVibeCheck() async throws {
        let backend = DemoBackend(seeded: true)
        let match = try #require(try await backend.fetchMatches().first)
        #expect(try await backend.dateIdea(matchID: match.matchID) == nil)
    }

    @Test func aGoodVibeCheckBringsAPartnerSpot() async throws {
        let backend = DemoBackend(seeded: true, vibeVerified: true)
        let match = try #require(try await backend.fetchMatches().first)
        let first = try #require(try await backend.dateIdea(matchID: match.matchID))
        #expect(first.spot != nil)
        #expect(try await backend.dateIdea(matchID: match.matchID)?.id == first.id, "both people see the same idea")
        let another = try #require(try await backend.nextDateIdea(matchID: match.matchID))
        #expect(another.spot?.id != first.spot?.id)
    }

    @Test func aFewIdeasADay() async throws {
        let backend = DemoBackend(seeded: true, vibeVerified: true)
        let match = try #require(try await backend.fetchMatches().first)
        _ = try await backend.dateIdea(matchID: match.matchID)
        for _ in 0..<3 { _ = try await backend.nextDateIdea(matchID: match.matchID) }
        await #expect(throws: GlimpseError.ideaLimit) {
            try await backend.nextDateIdea(matchID: match.matchID)
        }
    }

    @Test func topicsComeFromTheProfiles() async throws {
        let backend = DemoBackend(seeded: true)
        let match = try #require(try await backend.fetchMatches().first)
        let topics = try await backend.vibeTopics(matchID: match.matchID)
        #expect(topics.contains { $0.contains(match.city ?? "Tel Aviv") })
    }

    @Test func spotLinksFallBackToAppleMaps() {
        let spot = DateSpot(id: UUID(), name: "Lumen Café", category: .cafe, latitude: 32.07, longitude: 34.775)
        #expect(spot.mapsLink?.host == "maps.apple.com")
    }
}

/// Nudity checks run only where the viewer turned on Sensitive Content Warning.
@MainActor
struct SensitiveContentTests {
    @Test func offWhenThePhoneDoesNotAnalyze() async throws {
        let checker = SensitiveContentChecker.shared
        guard !checker.isAvailable else { return } // a phone with the setting on
        // No download and no analysis when the feature is off.
        #expect(try await checker.isSensitive(remoteURLString: "https://example.invalid/clip.mp4") == false)
    }
}
