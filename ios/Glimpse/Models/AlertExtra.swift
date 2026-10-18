import Foundation

/// A kind of alert someone on "Just messages" can add on its own, when it
/// becomes relevant (mirrors `profiles.push_extras`).
enum AlertExtra: String, Codable, CaseIterable, Identifiable, Sendable {
    case vibeCheck = "vibe_check"
    case newMatch = "new_match"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vibeCheck: String(localized: "Vibe Check reminders")
        case .newMatch: String(localized: "New matches")
        }
    }
}
