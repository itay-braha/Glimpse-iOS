import Foundation
@testable import Glimpse
import Testing

struct HeightTests {
    @Test func cardsDecodeAShownHeight() throws {
        let json = """
        {"id":"00000000-0000-4000-8000-000000000001","display_name":"Noa","age":27,"videos":[],"height_cm":168}
        """
        let card = try JSONDecoder.glimpse().decode(FeedProfile.self, from: Data(json.utf8))
        #expect(card.heightCm == 168)
    }

    @Test func aHiddenHeightIsJustAbsent() throws {
        let json = """
        {"id":"00000000-0000-4000-8000-000000000001","display_name":"Noa","age":27,"videos":[],"height_cm":null}
        """
        let card = try JSONDecoder.glimpse().decode(FeedProfile.self, from: Data(json.utf8))
        #expect(card.heightCm == nil)
    }

    @Test func decodesMyHeight() throws {
        let json = #"{"height_cm":181,"is_shown":false,"is_set":true}"#
        let mine = try JSONDecoder.glimpse().decode(HeightSetting.self, from: Data(json.utf8))
        #expect(mine == HeightSetting(heightCm: 181, isShown: false, isSet: true))
    }

    @Test func demoMirrorsTheServer() async throws {
        let backend = DemoBackend(seeded: false)
        #expect(try await backend.fetchMyHeight().isSet == false)

        // Showing needs a number.
        try await backend.setHeight(HeightSetting(heightCm: nil, isShown: true))
        #expect(try await backend.fetchMyHeight().isShown == false)

        try await backend.setHeight(HeightSetting(heightCm: 175, isShown: true))
        #expect(try await backend.fetchMyHeight() == HeightSetting(heightCm: 175, isShown: true))

        // Hiding keeps the number for later.
        try await backend.setHeight(HeightSetting(heightCm: nil, isShown: false))
        #expect(try await backend.fetchMyHeight() == HeightSetting(heightCm: 175, isShown: false))
    }

    @Test func someDemoCardsShowHeightAndSomeDont() {
        let feed = DemoData.feed()
        #expect(feed.contains { $0.heightCm != nil })
        #expect(feed.contains { $0.heightCm == nil })
        #expect(feed.compactMap(\.heightCm).allSatisfy { HeightSetting.range.contains($0) })
    }
}
