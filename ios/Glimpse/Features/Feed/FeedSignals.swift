import Foundation

/// Batches implicit feed signals and sends them in the background: every 15
/// events, every 20 seconds, and when the app leaves the foreground. Best effort;
/// a lost batch only means slightly less personal ranking.
@MainActor
final class FeedSignals {
    static let shared = FeedSignals()

    private var backend: (any GlimpseBackend)?
    private var queue: [FeedEvent] = []
    private var flushTask: Task<Void, Never>?

    private init() {}

    func configure(_ backend: any GlimpseBackend) {
        self.backend = backend
    }

    func record(_ kind: FeedEvent.Kind, target: UUID, dwellMs: Int? = nil) {
        queue.append(FeedEvent(target: target, kind: kind, dwellMs: dwellMs))
        if queue.count >= 15 {
            flush()
        } else if flushTask == nil {
            flushTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(20))
                self?.flush()
            }
        }
    }

    func flush() {
        flushTask?.cancel()
        flushTask = nil
        guard let backend, !queue.isEmpty else { return }
        let batch = Array(queue.prefix(50))
        queue.removeFirst(batch.count)
        Task { await backend.logFeedEvents(batch) }
        if !queue.isEmpty { flush() }
    }
}
