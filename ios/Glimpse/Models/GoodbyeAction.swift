import Foundation

/// What someone did with a kind-goodbye offer (recorded; declining is never a penalty).
enum GoodbyeAction: String, Sendable {
    case sent
    case dismissed
    case unmatchedWithoutNote = "unmatched_without_note"
    case keptChatting = "kept_chatting"
}
