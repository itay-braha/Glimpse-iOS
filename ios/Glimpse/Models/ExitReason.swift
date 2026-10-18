import Foundation

/// Private answer to "Why did this connection end?" (never shown to anyone).
enum ExitReason: String, CaseIterable, Identifiable, Sendable {
    case conversationDied = "conversation_died"
    case flakedOnDate = "flaked_on_date"
    case didntLookLikeVideo = "didnt_look_like_video"
    case inappropriate
    case notFeelingIt = "not_feeling_it"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .conversationDied: String(localized: "The conversation died")
        case .flakedOnDate: String(localized: "They flaked on a date")
        case .didntLookLikeVideo: String(localized: "They didn't look like their videos")
        case .inappropriate: String(localized: "They were inappropriate")
        case .notFeelingIt: String(localized: "I just wasn't feeling it")
        }
    }
}
