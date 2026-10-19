import Foundation

/// The private answer after a date: did they show up? Never shown to the other person.
/// A no-show is about the date itself; ghosting (disappearing from a chat) is separate
/// and lives in the exit survey.
enum DateOutcome: String, Codable, CaseIterable, Sendable {
    case great
    case noSpark = "no_spark"
    case noShow = "no_show"

    var label: String {
        switch self {
        case .great: String(localized: "Yes, it was great")
        case .noSpark: String(localized: "Yes, but no spark")
        case .noShow: String(localized: "No, they stood me up")
        }
    }
}
