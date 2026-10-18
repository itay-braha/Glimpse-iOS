import Foundation

/// Guided-recording prompts. Stored as keys so copy can change without migrations.
enum VibePrompt: String, CaseIterable, Identifiable, Sendable {
    // Inspiration cards on the "Let others get a Glimpse of YOU" hub.
    case bestFriend = "best_friend"
    case inMyElement = "in_my_element"
    case quickHello = "quick_hello"
    // Conversation starters.
    case hotTake = "hot_take"
    case redFlags = "red_flags"
    case sunday = "sunday"
    case greenFlag = "green_flag"
    case proudOf = "proud_of"
    case perfectDate = "perfect_date"
    case talent = "talent"
    case comfortSpot = "comfort_spot"

    var id: String { rawValue }

    /// The prompts featured in the inspiration carousel, in order.
    static let inspiration: [VibePrompt] = [.bestFriend, .inMyElement, .quickHello]

    var text: String {
        switch self {
        case .bestFriend: String(localized: "My best friend")
        case .inMyElement: String(localized: "In my element")
        case .quickHello: String(localized: "Quick hello")
        case .hotTake: String(localized: "A take I'll defend forever")
        case .redFlags: String(localized: "My most harmless red flag")
        case .sunday: String(localized: "My Sunday, in 15 seconds")
        case .greenFlag: String(localized: "The green flag I look for")
        case .proudOf: String(localized: "Something I'm weirdly proud of")
        case .perfectDate: String(localized: "Pitch me our first date")
        case .talent: String(localized: "A useless talent of mine")
        case .comfortSpot: String(localized: "My comfort spot in the city")
        }
    }

    var emoji: String {
        switch self {
        case .bestFriend: "🐶"
        case .inMyElement: "🏄‍♂️"
        case .quickHello: "🎤"
        case .hotTake: "🔥"
        case .redFlags: "🚩"
        case .sunday: "☀️"
        case .greenFlag: "💚"
        case .proudOf: "🏆"
        case .perfectDate: "🍷"
        case .talent: "🎩"
        case .comfortSpot: "📍"
        }
    }

    /// What to film, shown on the inspiration card and in the camera.
    var idea: String {
        switch self {
        case .bestFriend: String(localized: "Introduce your dog, your cat, or the friend who'd vouch for you.")
        case .inMyElement: String(localized: "Surfing, cooking, climbing, DJ-ing. Show the thing that makes you light up.")
        case .quickHello: String(localized: "Just you, saying hi. Your voice, your smile, 15 seconds.")
        default: text
        }
    }
}
