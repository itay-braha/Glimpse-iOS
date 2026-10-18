import Foundation

/// The private answer after a date: did they show up? Never shown to the other person.
enum DateOutcome: String, Codable, CaseIterable, Sendable {
    case great
    case noSpark = "no_spark"
    case ghosted

    var label: String {
        switch self {
        case .great: String(localized: "Yes, it was great")
        case .noSpark: String(localized: "Yes, but no spark")
        case .ghosted: String(localized: "No, they didn't come")
        }
    }
}
