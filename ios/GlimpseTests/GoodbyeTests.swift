import Foundation
@testable import Glimpse
import Testing

/// A kind goodbye: offered by the server now and then, never forced.
struct GoodbyeTests {
    @Test func decodesTheServersOffer() throws {
        let json = #"{"show":true,"prompt_id":"00000000-0000-4000-8000-000000000001","trigger":"stopped_replying"}"#
        let offer = try JSONDecoder().decode(GoodbyeOffer.self, from: Data(json.utf8))
        #expect(offer.show)
        #expect(offer.trigger == .stoppedReplying)
        let none = try JSONDecoder().decode(GoodbyeOffer.self, from: Data(#"{"show":false}"#.utf8))
        #expect(!none.show)
        #expect(none.promptID == nil)
    }

    @Test func eachMomentGetsFittingWords() {
        #expect(GoodbyeTemplate.choices(for: .vibeNoSpark).first == .afterVibeCheck)
        #expect(GoodbyeTemplate.choices(for: .stoppedReplying).first == .slowReply)
        for trigger in [GoodbyeTrigger.vibeNoSpark, .stoppedReplying, .unmatchAfterTheirMessage] {
            #expect(GoodbyeTemplate.choices(for: trigger).count == 3)
        }
    }

    @Test func notesAreAddressedAndShort() {
        for template in GoodbyeTemplate.allCases {
            let text = template.text(to: "Noa")
            #expect(text.contains("Noa"))
            #expect(text.count <= 280)
        }
    }

    @Test func noOfferInAShortChat() async throws {
        let backend = DemoBackend(seeded: true)
        let matches = try await backend.fetchMatches()
        for match in matches {
            let count = try await backend.fetchMessages(matchID: match.matchID).count
            if count < 6 {
                let offer = try await backend.goodbyeOffer(matchID: match.matchID, context: .unmatch)
                #expect(!offer.show, "only after a real conversation")
            }
        }
    }
}
