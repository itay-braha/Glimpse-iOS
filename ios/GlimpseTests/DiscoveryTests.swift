import Foundation
@testable import Glimpse
import Testing

/// Client side of discovery v4: signals sent to the server, and how widened
/// suggestions are labelled (the ranking itself lives in SQL; see
/// supabase/tests/database/glimpse_discovery.test.sql).
struct DiscoveryTests {
    @Test func feedEventsEncodeForTheServer() throws {
        let event = FeedEvent(target: DemoData.id(7), kind: .linkOpen, dwellMs: 5300)
        let json = try #require(String(data: JSONEncoder().encode(event), encoding: .utf8))
        #expect(json.contains("\"kind\":\"link_open\""))
        #expect(json.contains("\"dwell_ms\":5300"))
        #expect(json.contains("\"target\""))
    }

    @Test func widenedCardsSayWhyTheyreThere() throws {
        let json = Data("""
        {"id":"00000000-0000-4000-8000-000000000009","display_name":"Noa","age":27,"videos":[],
         "discovery_note":"wider_distance"}
        """.utf8)
        let profile = try JSONDecoder.glimpse().decode(FeedProfile.self, from: json)
        #expect(profile.discoveryNote == .widerDistance)
        #expect(profile.discoveryNote?.text == "A little further than usual")
    }

    @Test func unknownNotesStillDecode() throws {
        let json = Data("""
        {"id":"00000000-0000-4000-8000-000000000010","display_name":"Noa","age":27,"videos":[],
         "discovery_note":"something_new"}
        """.utf8)
        #expect(try JSONDecoder.glimpse().decode(FeedProfile.self, from: json).discoveryNote == .other)
    }

    @Test func demoFeedPutsWidenedSuggestionsLast() async throws {
        let feed = await DemoBackend(seeded: true).fetchFeed(limit: 50)
        let firstNoted = try #require(feed.firstIndex { $0.discoveryNote != nil })
        #expect(feed[firstNoted...].allSatisfy { $0.discoveryNote != nil })
    }

    @Test @MainActor func signalsAreBatchedToTheBackend() async throws {
        let backend = DemoBackend(seeded: true)
        FeedSignals.shared.configure(backend)
        for _ in 0..<15 {
            FeedSignals.shared.record(.view, target: DemoData.id(101), dwellMs: 4000)
        }
        try await Task.sleep(for: .milliseconds(200))
        #expect(await backend.loggedFeedEvents.count == 15)
    }
}
