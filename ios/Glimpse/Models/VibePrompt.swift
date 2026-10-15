import Foundation

/// Guided-recording prompts. Stored as keys so copy can change without migrations.
enum VibePrompt: String, CaseIterable, Identifiable, Sendable {
    case hotTake = "hot_take"
    case redFlags = "red_flags"
    case sunday = "sunday"
    case greenFlag = "green_flag"
    case proudOf = "proud_of"
    case perfectDate = "perfect_date"
    case talent = "talent"
    case comfortSpot = "comfort_spot"

    var id: String { rawValue }

    var text: String {
        switch self {
        case .hotTake: "A take I'll defend forever"
        case .redFlags: "My most harmless red flag"
        case .sunday: "My Sunday, in 15 seconds"
        case .greenFlag: "The green flag I look for"
        case .proudOf: "Something I'm weirdly proud of"
        case .perfectDate: "Pitch me our first date"
        case .talent: "A useless talent of mine"
        case .comfortSpot: "My comfort spot in the city"
        }
    }
}
