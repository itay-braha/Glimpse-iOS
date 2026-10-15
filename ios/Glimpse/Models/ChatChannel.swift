import Foundation

/// A live chat subscription: new messages, edits to messages (read receipts,
/// unsends), reactions, the other person's typing pings, and a way to send our
/// own typing ping.
struct ChatChannel: Sendable {
    let messages: AsyncStream<ChatMessage>
    let updates: AsyncStream<ChatMessage>
    let reactions: AsyncStream<MessageReaction>
    let typing: AsyncStream<Void>
    let sendTyping: @Sendable () async -> Void
    let close: @Sendable () async -> Void
}
