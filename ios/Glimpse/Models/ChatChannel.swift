import Foundation

/// A live chat subscription: new messages, the other person's typing pings,
/// and a way to send our own typing ping.
struct ChatChannel: Sendable {
    let messages: AsyncStream<ChatMessage>
    let typing: AsyncStream<Void>
    let sendTyping: @Sendable () async -> Void
    let close: @Sendable () async -> Void
}
