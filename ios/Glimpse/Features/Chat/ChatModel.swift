import Foundation
import Observation

@MainActor
@Observable
final class ChatModel {
    let match: MatchSummary
    private(set) var messages: [ChatMessage] = []
    /// messageID → (userID → emoji). One reaction per person per message.
    private(set) var reactions: [UUID: [UUID: String]] = [:]
    private(set) var isOtherTyping = false
    private(set) var isLoading = true
    private(set) var hasEnded = false
    private(set) var vibe: VibeCheckState?
    /// A first-date idea, once a Vibe Check went well.
    private(set) var dateIdea: DateIdea?
    /// A date the two of them are planning, or had (until the private check-in).
    private(set) var plannedDate: PlannedDate?
    private(set) var isFrozen: Bool
    var draft = ""
    /// The message being answered (swipe a bubble, or "Reply" in its menu).
    var replyingTo: ChatMessage?
    /// Playable links for voice messages and video notes, by storage path.
    private(set) var mediaURLs: [String: URL] = [:]
    private(set) var isSendingMedia = false
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

    /// Loads history, then listens for live messages, edits, reactions and typing until cancelled.
    func run(using backend: any GlimpseBackend, myID: UUID?) async {
        hasEnded = !(await isStillActive(using: backend))
        do {
            messages = try await backend.fetchMessages(matchID: match.matchID)
            await resolveMedia(for: messages, using: backend)
            for reaction in (try? await backend.fetchReactions(matchID: match.matchID)) ?? [] {
                apply(reaction)
            }
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
                await resolveMedia(for: [message], using: backend)
            }
        }
        let updateTask = Task {
            for await message in channel.updates {
                replace(message)
            }
        }
        let reactionTask = Task {
            for await reaction in channel.reactions {
                apply(reaction)
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
            await updateTask.value
            await reactionTask.value
            await typingTask.value
            await vibeTask.value
        } onCancel: {
            messageTask.cancel()
            updateTask.cancel()
            reactionTask.cancel()
            typingTask.cancel()
            vibeTask.cancel()
        }

        await channel.close()
        self.channel = nil
    }

    func send(using backend: any GlimpseBackend) async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let quoting = replyingTo
        draft = ""
        replyingTo = nil
        do {
            let message = try await backend.send(body, matchID: match.matchID, replyTo: quoting?.id)
            insert(message)
        } catch {
            draft = body
            replyingTo = quoting
            if (error as? GlimpseError) == nil, messages.isEmpty == false {
                hasEnded = !(await isStillActive(using: backend))
            }
            errorMessage = hasEnded ? "This connection has ended." : GlimpseError.describe(error)
        }
    }

    // MARK: Voice messages and video notes

    func sendMedia(_ recording: ChatMediaRecorder.Recording, using backend: any GlimpseBackend) async {
        guard !hasEnded else { return }
        let quoting = replyingTo
        replyingTo = nil
        isSendingMedia = true
        defer { isSendingMedia = false }
        do {
            let message = try await backend.sendMedia(
                recording.kind, fileURL: recording.fileURL, duration: recording.duration,
                matchID: match.matchID, replyTo: quoting?.id
            )
            if let path = message.mediaPath, recording.fileURL.isFileURL {
                mediaURLs[path] = recording.fileURL // play our own copy straight away
            }
            await resolveMedia(for: [message], using: backend)
            insert(message)
        } catch {
            replyingTo = quoting
            errorMessage = GlimpseError.describe(error)
        }
    }

    func mediaURL(for message: ChatMessage) -> URL? {
        message.mediaPath.flatMap { mediaURLs[$0] }
    }

    private func resolveMedia(for batch: [ChatMessage], using backend: any GlimpseBackend) async {
        let paths = batch.compactMap(\.mediaPath).filter { mediaURLs[$0] == nil }
        guard !paths.isEmpty else { return }
        mediaURLs.merge(await backend.chatMediaURLs(for: paths)) { current, _ in current }
    }

    // MARK: Replies, reactions, deleting

    func message(withID id: UUID?) -> ChatMessage? {
        guard let id else { return nil }
        return messages.first { $0.id == id }
    }

    /// Emojis on a message, mine first-class: tapping my own emoji again removes it.
    func reactions(on message: ChatMessage) -> [UUID: String] {
        reactions[message.id] ?? [:]
    }

    func react(to message: ChatMessage, with emoji: String, myID: UUID?, using backend: any GlimpseBackend) async {
        guard let myID, !message.isUnsent, !hasEnded else { return }
        let previous = reactions[message.id]?[myID]
        let next: String? = previous == emoji ? nil : emoji
        apply(MessageReaction(messageID: message.id, userID: myID, matchID: match.matchID, emoji: next))
        do {
            try await backend.react(to: message.id, emoji: next)
        } catch {
            apply(MessageReaction(messageID: message.id, userID: myID, matchID: match.matchID, emoji: previous))
            errorMessage = GlimpseError.describe(error)
        }
    }

    /// Your own messages, any time (the safety team keeps a copy for 30 days).
    func canDelete(_ message: ChatMessage, myID: UUID?) -> Bool {
        message.senderID == myID && !message.isUnsent && !hasEnded
    }

    func delete(_ message: ChatMessage, using backend: any GlimpseBackend) async {
        do {
            try await backend.deleteMessage(message.id)
            var deleted = message
            deleted.deletedAt = .now
            deleted.body = "Message deleted"
            deleted.mediaPath = nil
            replace(deleted)
            reactions[message.id] = nil
            if replyingTo?.id == message.id { replyingTo = nil }
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    // MARK: Date ideas

    func refreshDateIdea(using backend: any GlimpseBackend) async {
        guard !hasEnded else { return }
        dateIdea = (try? await backend.dateIdea(matchID: match.matchID)) ?? dateIdea
        plannedDate = try? await backend.plannedDate(matchID: match.matchID)
    }

    /// Picks a time at the current idea's place; the other person accepts or suggests another.
    func proposeDate(at date: Date, using backend: any GlimpseBackend) async -> Bool {
        guard let idea = dateIdea else { return false }
        do {
            plannedDate = try await backend.proposeDate(matchID: match.matchID, ideaID: idea.id, at: date)
            return true
        } catch {
            errorMessage = GlimpseError.describe(error)
            return false
        }
    }

    func respondToDate(accept: Bool, using backend: any GlimpseBackend) async {
        guard let plan = plannedDate else { return }
        do {
            plannedDate = try await backend.respondDate(plan.id, accept: accept)
            if !accept { plannedDate = nil }
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    func cancelDate(using backend: any GlimpseBackend) async {
        guard let plan = plannedDate else { return }
        try? await backend.cancelDate(plan.id)
        plannedDate = nil
    }

    /// Moves a plan (before the date, or from the check-in) to a new time.
    func rescheduleDate(_ dateID: UUID, at date: Date, using backend: any GlimpseBackend) async -> Bool {
        do {
            plannedDate = try await backend.rescheduleDate(dateID, at: date)
            return true
        } catch {
            errorMessage = GlimpseError.describe(error)
            return false
        }
    }

    func checkIn(_ outcome: DateOutcome, using backend: any GlimpseBackend) async {
        guard let plan = plannedDate else { return }
        try? await backend.checkInDate(plan.id, outcome: outcome)
        plannedDate = nil
    }

    func anotherDateIdea(using backend: any GlimpseBackend) async {
        do {
            if let next = try await backend.nextDateIdea(matchID: match.matchID) { dateIdea = next }
        } catch {
            errorMessage = GlimpseError.describe(error)
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

    // MARK: Live updates

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

    /// Edits to a message we have: read receipts, unsends.
    private func replace(_ message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index] = message
        if message.isUnsent { reactions[message.id] = nil }
    }

    private func apply(_ reaction: MessageReaction) {
        var onMessage = reactions[reaction.messageID] ?? [:]
        onMessage[reaction.userID] = reaction.emoji
        reactions[reaction.messageID] = onMessage.isEmpty ? nil : onMessage
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
