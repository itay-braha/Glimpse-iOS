import Foundation
@testable import Glimpse
import Testing

/// Replies, reactions, unsend and alert scope against the demo backend (the
/// database enforces the same rules; see supabase/tests/database/glimpse_chat.test.sql).
struct ChatTests {
    private func firstMatch(_ backend: DemoBackend) async throws -> MatchSummary {
        try #require(try await backend.fetchMatches().first)
    }

    @Test func repliesKeepTheirQuote() async throws {
        let backend = DemoBackend(seeded: true)
        let match = try await firstMatch(backend)
        let history = try await backend.fetchMessages(matchID: match.matchID)
        let quoted = try #require(history.first)
        let sent = try await backend.send("Sunset it is", matchID: match.matchID, replyTo: quoted.id)
        #expect(sent.replyTo == quoted.id)
        #expect(history.contains { $0.replyTo != nil }) // the seeded chat shows a reply too
    }

    @Test func oneReactionPerPersonAndItCanBeRemoved() async throws {
        let backend = DemoBackend(seeded: true)
        let match = try await firstMatch(backend)
        let message = try #require(try await backend.fetchMessages(matchID: match.matchID).first)
        try await backend.react(to: message.id, emoji: "😂")
        try await backend.react(to: message.id, emoji: "🔥")
        let mine = try await backend.fetchReactions(matchID: match.matchID)
            .filter { $0.messageID == message.id && $0.userID == DemoData.meID }
        #expect(mine.map(\.emoji) == ["🔥"])
        try await backend.react(to: message.id, emoji: nil)
        let cleared = try await backend.fetchReactions(matchID: match.matchID)
            .first { $0.messageID == message.id && $0.userID == DemoData.meID }
        #expect(cleared?.emoji == nil)
    }

    @Test func onlyOwnMessagesCanBeDeletedAndTheOriginalIsKept() async throws {
        let backend = DemoBackend(seeded: true)
        let match = try await firstMatch(backend)
        let theirs = try #require(try await backend.fetchMessages(matchID: match.matchID).first { $0.senderID != DemoData.meID })
        await #expect(throws: (any Error).self) {
            try await backend.deleteMessage(theirs.id)
        }
        let mine = try await backend.send("Oops wrong chat", matchID: match.matchID)
        try await backend.deleteMessage(mine.id)
        let after = try await backend.fetchMessages(matchID: match.matchID).first { $0.id == mine.id }
        #expect(after?.isUnsent == true)
        #expect(after?.body == "Message deleted")
        #expect(await backend.deletedArchive[mine.id]?.body == "Oops wrong chat")
    }

    @Test func voiceAndVideoMessagesKeepTheirLength() async throws {
        let backend = DemoBackend(seeded: true)
        let match = try await firstMatch(backend)
        let voice = try await backend.sendMedia(
            .voice, fileURL: URL(fileURLWithPath: "/tmp/v.m4a"), duration: 200, matchID: match.matchID, replyTo: nil
        )
        #expect(voice.resolvedKind == .voice)
        #expect(voice.mediaDuration == MessageKind.voice.maxDuration) // capped at 2 minutes
        let video = try await backend.sendMedia(
            .video, fileURL: URL(fileURLWithPath: "/tmp/n.mp4"), duration: 12, matchID: match.matchID, replyTo: voice.id
        )
        #expect(video.resolvedKind == .video)
        #expect(video.replyTo == voice.id)
        #expect(MessageKind.video.maxDuration == 60)
    }

    @Test func olderMessagesWithoutAKindAreText() throws {
        let json = Data("""
        {"id":"00000000-0000-4000-8000-000000000011","match_id":"00000000-0000-4000-8000-000000000012",
         "sender_id":"00000000-0000-4000-8000-000000000013","body":"hi","created_at":"2026-10-01T10:00:00Z"}
        """.utf8)
        let message = try JSONDecoder.glimpse().decode(ChatMessage.self, from: json)
        #expect(message.resolvedKind == .text)
    }

    @Test func alertChoiceIsSaved() async throws {
        let backend = DemoBackend(seeded: true)
        try await backend.setPushScope(.messages)
        #expect(try await backend.fetchMyProfile()?.pushScope == .messages)
    }
}
