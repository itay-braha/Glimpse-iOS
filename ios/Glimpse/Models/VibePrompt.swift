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
        case .bestFriend: "My best friend"
        case .inMyElement: "In my element"
        case .quickHello: "Quick hello"
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
        case .bestFriend: "Introduce your dog, your cat, or the friend who'd vouch for you."
        case .inMyElement: "Surfing, cooking, climbing, DJ-ing. Show the thing that makes you light up."
        case .quickHello: "Just you, saying hi. Your voice, your smile, 15 seconds."
        default: text
        }
    }
}
