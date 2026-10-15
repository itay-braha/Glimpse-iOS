import Foundation
import Observation

@MainActor
@Observable
final class MatchesModel {
    private(set) var matches: [MatchSummary] = []
    private(set) var avatarURLs: [String: URL] = [:]
    private(set) var notices: [AppNotification] = []
    private(set) var likesTotal = 0
    private(set) var secondChances: [SecondChance] = []
    private(set) var missedCount = 0
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?

    static let cap = 20

    var atCapacity: Bool { matches.count >= Self.cap }
    var newMatches: [MatchSummary] { matches.filter { $0.messageCount == 0 } }
    var conversations: [MatchSummary] { matches.filter { $0.messageCount > 0 } }

    func load(using backend: any GlimpseBackend) async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            let fresh = try await backend.fetchMatches()
            let paths = fresh.compactMap(\.thumbnailPath)
            if !paths.isEmpty {
                avatarURLs.merge(await backend.mediaURLs(for: paths)) { _, new in new }
            }
            matches = fresh
            errorMessage = nil
            notices = ((try? await backend.notifications()) ?? [])
                .filter { $0.readAt == nil && $0.kind == .connectionEnded }
            likesTotal = (try? await backend.likesReceived().total) ?? 0
            secondChances = (try? await backend.secondChances()) ?? []
            missedCount = (try? await backend.missedConnections().count) ?? 0
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    func unmatch(_ match: MatchSummary, using backend: any GlimpseBackend) async {
        do {
            try await backend.unmatch(match.matchID)
            matches.removeAll { $0.matchID == match.matchID }
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    func toggleFreeze(_ match: MatchSummary, using backend: any GlimpseBackend) async throws {
        try await backend.setFrozen(match.matchID, frozen: !(match.isFrozen ?? false))
        await load(using: backend)
    }

    /// Accepting re-creates the match (the 20-cap still applies).
    func respond(to request: SecondChance, accept: Bool, using backend: any GlimpseBackend) async -> MatchSummary? {
        do {
            let result = try await backend.respondToSecondChance(request.id, accept: accept)
            await load(using: backend)
            guard result.matched, let matchID = result.matchID else { return nil }
            return matches.first { $0.matchID == matchID }
        } catch {
            errorMessage = GlimpseError.describe(error)
            return nil
        }
    }

    func dismiss(_ notice: AppNotification, using backend: any GlimpseBackend) async {
        notices.removeAll { $0.id == notice.id }
        try? await backend.markNotificationsRead([notice.id])
    }

    func avatarURL(for match: MatchSummary) -> URL? {
        match.thumbnailPath.flatMap { avatarURLs[$0] }
    }

    /// The connection the auto-boot engine would release if a new match lands now.
    func isNextToRelease(_ match: MatchSummary) -> Bool {
        atCapacity && match.bootRank == 1
    }
}
