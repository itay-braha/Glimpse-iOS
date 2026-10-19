import Foundation

/// Private answer to "Why did this connection end?" (never shown to anyone). It only
/// feeds the behavioral score; "Ghosted" on its own never leads to a penalty.
enum ExitReason: String, CaseIterable, Identifiable, Sendable {
    case noChemistry = "no_chemistry"
    case conversationDied = "conversation_died"
    case ghosted
    case inappropriate
    case didntLookLikeVideo = "didnt_look_like_video"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noChemistry: String(localized: "No chemistry")
        case .conversationDied: String(localized: "Conversation died")
        case .ghosted: String(localized: "Ghosted / Disappeared")
        case .inappropriate: String(localized: "Inappropriate behavior")
        case .didntLookLikeVideo: String(localized: "They didn't look like their videos")
        }
    }
}
