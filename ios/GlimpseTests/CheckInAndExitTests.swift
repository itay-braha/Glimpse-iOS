import Foundation
@testable import Glimpse
import Testing

/// No-shows (the date check-in) and ghosting (the exit survey) are different things.
struct CheckInAndExitTests {
    @Test func aNoShowIsStoodUp() throws {
        #expect(DateOutcome.noShow.rawValue == "no_show")
        #expect(DateOutcome.noShow.label == "They stood me up")
        let decoded = try JSONDecoder().decode(DateOutcome.self, from: Data(#""no_show""#.utf8))
        #expect(decoded == .noShow)
    }

    @Test func theCheckInCoversHowDatesReallyGo() {
        // Moved, called off, couldn't make it and "something felt off" are all answers,
        // so a missed date isn't forced into "they stood me up".
        let raw = DateOutcome.choices.map(\.rawValue)
        #expect(raw == ["great", "no_spark", "rescheduled", "called_off", "i_missed", "no_show", "uncomfortable"])
        #expect(!DateOutcome.choices.contains(.skipped), "Prefer not to say is shown apart")
    }

    @Test func movingADateSendsItBackForAYes() async throws {
        let backend = DemoBackend(seeded: true, vibeVerified: true)
        let matchID = try #require(try await backend.fetchMatches().first?.matchID)
        let idea = try #require(try await backend.dateIdea(matchID: matchID))
        let plan = try await backend.proposeDate(matchID: matchID, ideaID: idea.id, at: .now.addingTimeInterval(86_400))
        let later = Date.now.addingTimeInterval(2 * 86_400)
        let moved = try await backend.rescheduleDate(plan.id, at: later)
        #expect(moved.status == .proposed)
        #expect(moved.startsAt == later)
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
