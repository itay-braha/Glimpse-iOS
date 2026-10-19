import Foundation
@testable import Glimpse
import Testing

/// No-shows (the date check-in) and ghosting (the exit survey) are different things.
struct CheckInAndExitTests {
    @Test func aNoShowIsStoodUp() throws {
        #expect(DateOutcome.noShow.rawValue == "no_show")
        #expect(DateOutcome.noShow.label == "No, they stood me up")
        let decoded = try JSONDecoder().decode(DateOutcome.self, from: Data(#""no_show""#.utf8))
        #expect(decoded == .noShow)
    }

    @Test func theExitSurveyOffersTheFourAnswers() {
        let labels = ExitReason.allCases.map(\.label)
        for expected in ["No chemistry", "Conversation died", "Ghosted / Disappeared", "Inappropriate behavior"] {
            #expect(labels.contains(expected))
        }
        // No-shows are asked about after the date, not here.
        #expect(!ExitReason.allCases.map(\.rawValue).contains("flaked_on_date"))
        #expect(ExitReason.ghosted.rawValue == "ghosted")
    }
}
