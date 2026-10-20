import Foundation

/// When the app asks whether a kind goodbye would fit.
enum GoodbyeContext: String, Sendable {
    case chatOpen = "chat_open"
    case unmatch
}
