import Foundation
@testable import Glimpse
import Testing

struct ParsingTests {
    @Test(arguments: [
        "2026-10-15T06:15:05.123456+00:00",
        "2026-10-15 06:15:05.123456+00",
        "2026-10-15T06:15:05Z",
        "2026-10-15T06:15:05+00:00",
        "2026-10-15T06:15:05.1",
    ])
    func postgresTimestamps(raw: String) throws {
        let date = try #require(FlexibleDate.parse(raw))
        let components = Calendar(identifier: .gregorian).dateComponents(in: .gmt, from: date)
        #expect(components.year == 2026)
        #expect(components.month == 10)
        #expect(components.hour == 6)
        #expect(components.second == 5)
    }

    @Test func decodesRealtimeMessageRecords() throws {
        let json = """
        {"id":"4b1d0d5e-8f7a-4b0e-9a55-1c2d3e4f5a6b","match_id":"00000000-0000-4000-8000-000000000001",
         "sender_id":"00000000-0000-4000-8000-000000000002","body":"hey","created_at":"2026-10-15 06:15:05.5+00","read_at":null}
        """
        let message = try JSONDecoder.glimpse().decode(ChatMessage.self, from: Data(json.utf8))
        #expect(message.body == "hey")
        #expect(message.readAt == nil)
    }

    @Test func phoneNumbersNormaliseToE164() {
        #expect(PhoneNumber.e164(dialCode: "972", national: "054-123-4567") == "+972541234567")
        #expect(PhoneNumber.e164(dialCode: "1", national: "(415) 555-0100") == "+14155550100")
        #expect(PhoneNumber.e164(dialCode: "44", national: "12") == nil)
    }

    @Test func birthdatesRoundTrip() throws {
        let date = try #require(BirthdateFormat.date(from: "1998-05-14"))
        #expect(BirthdateFormat.string(from: date).hasPrefix("1998-05-1"))
    }
}
