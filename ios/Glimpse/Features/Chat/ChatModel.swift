import Foundation
import Observation

@MainActor
@Observable
final class ChatModel {
    let match: MatchSummary
    private(set) var messages: [ChatMessage] = []
    private(set) var isOtherTyping = false
    private(set) var isLoading = true
    private(set) var hasEnded = false
    private(set) var vibe: VibeCheckState?
    private(set) var isFrozen: Bool
    var draft = ""
    var errorMessage: String?

    private var channel: ChatChannel?
    private var typingResetTask: Task<Void, Never>?
    private var lastTypingPing = Date.distantPast

    init(match: MatchSummary) {
        self.match = match
        isFrozen = match.isFrozen ?? false
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasEnded
    }

    /// Loads history, then listens for live messages and typing until cancelled.
    func run(using backend: any GlimpseBackend, myID: UUID?) async {
        hasEnded = !(await isStillActive(using: backend))
        do {
            messages = try await backend.fetchMessages(matchID: match.matchID)
            try? await backend.markRead(matchID: match.matchID)
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
        isLoading = false
        if !hasEnded { await refreshVibe(using: backend) }

        let channel = await backend.openChannel(matchID: match.matchID)
        self.channel = channel

        let messageTask = Task {
            for await message in channel.messages {
                receive(message, myID: myID, backend: backend)
            }
        }
        let typingTask = Task {
            for await _ in channel.typing {
                showTyping()
            }
        }
        // Eligibility and scheduling change over time (and on the other phone).
        let vibeTask = Task {
            while !Task.isCancelled && !hasEnded {
                try? await Task.sleep(for: .seconds(20))
                await refreshVibe(using: backend)
            }
        }
        await withTaskCancellationHandler {
            await messageTask.value
            await typingTask.value
            await vibeTask.value
        } onCancel: {
            messageTask.cancel()
            typingTask.cancel()
            vibeTask.cancel()
        }

        await channel.close()
        self.channel = nil
    }

    func send(using backend: any GlimpseBackend) async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        draft = ""
        do {
            let message = try await backend.send(body, matchID: match.matchID)
            insert(message)
        } catch {
            draft = body
            if (error as? GlimpseError) == nil, messages.isEmpty == false {
                hasEnded = !(await isStillActive(using: backend))
            }
            errorMessage = hasEnded ? "This connection has ended." : GlimpseError.describe(error)
        }
    }

    // MARK: Vibe Check

    func refreshVibe(using backend: any GlimpseBackend) async {
        if let fresh = try? await backend.vibeCheck(matchID: match.matchID) {
            vibe = fresh
        }
    }

    func vibeAction(using backend: any GlimpseBackend, _ action: @MainActor () async throws -> Void) async {
        do {
            try await action()
            errorMessage = nil
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
        await refreshVibe(using: backend)
    }

    // MARK: Freeze

    func toggleFreeze(using backend: any GlimpseBackend) async throws {
        let target = !isFrozen
        try await backend.setFrozen(match.matchID, frozen: target)
        isFrozen = target
    }

    func draftChanged() {
        guard let channel, Date.now.timeIntervalSince(lastTypingPing) > 2 else { return }
        lastTypingPing = .now
        Task { await channel.sendTyping() }
    }

    private func receive(_ message: ChatMessage, myID: UUID?, backend: any GlimpseBackend) {
        insert(message)
        if message.senderID != myID {
            isOtherTyping = false
            Task { try? await backend.markRead(matchID: match.matchID) }
        }
    }

    private func insert(_ message: ChatMessage) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
        messages.sort { $0.createdAt < $1.createdAt }
    }

    private func showTyping() {
        isOtherTyping = true
        typingResetTask?.cancel()
        typingResetTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            isOtherTyping = false
        }
    }

    private func isStillActive(using backend: any GlimpseBackend) async -> Bool {
        guard let matches = try? await backend.fetchMatches() else { return true }
        return matches.contains { $0.matchID == match.matchID }
    }
}
