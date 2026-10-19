import Foundation

/// The private answer after a date: how it went. Never shown to the other person.
/// Only "They stood me up" counts toward the no-show rules (and not when the other
/// person says the date was moved or called off). Ghosting a chat is separate and lives
/// in the exit survey.
enum DateOutcome: String, Codable, CaseIterable, Sendable {
    case great
    case noSpark = "no_spark"
    case rescheduled
    case calledOff = "called_off"
    case iMissed = "i_missed"
    case noShow = "no_show"
    case uncomfortable
    case skipped

    /// The answers offered, in order ("Prefer not to say" is shown apart).
    static let choices: [DateOutcome] = [.great, .noSpark, .rescheduled, .calledOff, .iMissed, .noShow, .uncomfortable]

    var label: String {
        switch self {
        case .great: String(localized: "We met, it was great")
        case .noSpark: String(localized: "We met, but no spark")
        case .rescheduled: String(localized: "We moved it to another time")
        case .calledOff: String(localized: "We called it off")
        case .iMissed: String(localized: "I couldn't make it")
        case .noShow: String(localized: "They stood me up")
        case .uncomfortable: String(localized: "Something felt off")
        case .skipped: String(localized: "Prefer not to say")
        }
    }

    var symbol: String {
        switch self {
        case .great: "heart.fill"
        case .noSpark: "hand.wave"
        case .rescheduled: "calendar.badge.clock"
        case .calledOff: "calendar.badge.minus"
        case .iMissed: "person.fill.questionmark"
        case .noShow: "person.slash"
        case .uncomfortable: "exclamationmark.shield"
        case .skipped: "minus"
        }
    }
}
