import Foundation

/// A live signaling subscription for one Vibe Check.
struct VibeSignalChannel: Sendable {
    let signals: AsyncStream<VibeSignal>
    let send: @Sendable (VibeSignal) async -> Void
    let close: @Sendable () async -> Void
}
