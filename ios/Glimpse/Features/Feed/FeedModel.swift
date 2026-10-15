import Foundation
import Observation

enum LikeOutcome {
    case matched(MatchCelebration)
    case liked
    case outOfLikes
    case outOfViews
    case failed
}

struct MatchCelebration: Identifiable, Equatable {
    let match: MatchSummary
    let booted: BootedConnection?
    var id: UUID { match.matchID }
}

@MainActor
@Observable
final class FeedModel {
    private(set) var profiles: [FeedProfile] = []
    private(set) var playableURLs: [String: URL] = [:]
    private(set) var capacity: CapacityStatus = .empty
    private(set) var quota: LikeQuota?
    private(set) var density: DensityStatus = .open
    private(set) var pausedUntil: Date?

    /// Free members have seen today's new profiles.
    var viewsExhausted: Bool { quota?.viewsRemaining == 0 }
    private(set) var likedIDs: Set<UUID> = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var currentID: UUID?
    var celebration: MatchCelebration?
    var errorMessage: String?

    private var decidedIDs: Set<UUID> = []
    private var lastVisibleID: UUID?
    private var isFetchingMore = false

    func load(using backend: any GlimpseBackend) async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        if let state = try? await backend.accountState(), let until = state.pausedUntil, until > .now {
            pausedUntil = until
        } else {
            pausedUntil = nil
        }
        density = (try? await backend.densityStatus()) ?? .open
        do {
            async let feed = backend.fetchFeed(limit: 10)
            async let status = backend.capacityStatus()
            let (fresh, capacityStatus) = try await (feed, status)
            capacity = capacityStatus
            quota = try? await backend.likeQuota()
            await resolveMedia(for: fresh, using: backend)
            profiles = fresh
            currentID = fresh.first?.id
            lastVisibleID = currentID
            errorMessage = nil
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    func refreshCapacity(using backend: any GlimpseBackend) async {
        if let status = try? await backend.capacityStatus() {
            capacity = status
        }
    }

    /// Scrolling past someone without liking them records a pass, so nobody is shown twice.
    func visibleProfileChanged(to id: UUID?, using backend: any GlimpseBackend) {
        if let previous = lastVisibleID, previous != id, !decidedIDs.contains(previous) {
            decidedIDs.insert(previous)
            Task { _ = try? await backend.swipe(on: previous, liked: false) }
        }
        lastVisibleID = id
        prefetch(after: id)

        if let id, let index = profiles.firstIndex(where: { $0.id == id }), index >= profiles.count - 3 {
            Task { await loadMore(using: backend) }
        }
    }

    func refreshQuota(using backend: any GlimpseBackend) async {
        if let fresh = try? await backend.likeQuota() {
            quota = fresh
        }
    }

    func like(_ profile: FeedProfile, using backend: any GlimpseBackend) async -> LikeOutcome {
        guard !decidedIDs.contains(profile.id) else { return .failed }
        decidedIDs.insert(profile.id)
        likedIDs.insert(profile.id)
        do {
            let result = try await backend.swipe(on: profile.id, liked: true)
            if let remaining = result.likesRemaining {
                quota?.remaining = remaining
            }
            await refreshCapacity(using: backend)
            guard result.matched, let matchID = result.matchID else {
                advance(from: profile.id)
                return .liked
            }
            let match = MatchSummary(
                matchID: matchID,
                otherUserID: profile.id,
                displayName: profile.displayName,
                age: profile.age,
                city: profile.city,
                thumbnailPath: profile.videos.first?.thumbnailPath,
                createdAt: .now,
                lastMessageAt: nil,
                messageCount: 0,
                lastMessageBody: nil,
                lastMessageMine: nil,
                unreadCount: 0,
                bootRank: 0
            )
            let celebration = MatchCelebration(match: match, booted: result.booted)
            self.celebration = celebration
            return .matched(celebration)
        } catch GlimpseError.outOfLikes {
            decidedIDs.remove(profile.id)
            likedIDs.remove(profile.id)
            await refreshQuota(using: backend)
            return .outOfLikes
        } catch GlimpseError.outOfViews {
            decidedIDs.remove(profile.id)
            likedIDs.remove(profile.id)
            await refreshQuota(using: backend)
            profiles.removeAll()
            return .outOfViews
        } catch {
            decidedIDs.remove(profile.id)
            likedIDs.remove(profile.id)
            errorMessage = GlimpseError.describe(error)
            return .failed
        }
    }

    func resume(using backend: any GlimpseBackend) async {
        _ = try? await backend.setPause(days: 0)
        pausedUntil = nil
        await load(using: backend)
    }

    func pass(_ profile: FeedProfile, using backend: any GlimpseBackend) {
        guard !decidedIDs.contains(profile.id) else { return }
        decidedIDs.insert(profile.id)
        Task { _ = try? await backend.swipe(on: profile.id, liked: false) }
        advance(from: profile.id)
    }

    func remove(_ userID: UUID) {
        decidedIDs.insert(userID)
        advance(from: userID)
        profiles.removeAll { $0.id == userID }
    }

    func dismissCelebration() {
        if let celebration {
            advance(from: celebration.match.otherUserID)
        }
        celebration = nil
    }

    private func advance(from id: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let next = profiles.index(after: index)
        if next < profiles.endIndex {
            currentID = profiles[next].id
        }
    }

    private func loadMore(using backend: any GlimpseBackend) async {
        guard !isFetchingMore else { return }
        isFetchingMore = true
        defer { isFetchingMore = false }
        guard let more = try? await backend.fetchFeed(limit: 10) else { return }
        let known = Set(profiles.map(\.id))
        let fresh = more.filter { !known.contains($0.id) && !decidedIDs.contains($0.id) }
        guard !fresh.isEmpty else { return }
        await resolveMedia(for: fresh, using: backend)
        profiles.append(contentsOf: fresh)
    }

    private func resolveMedia(for batch: [FeedProfile], using backend: any GlimpseBackend) async {
        let paths = batch.flatMap { $0.videos.compactMap(\.storagePath) }
        let signed = await backend.mediaURLs(for: paths)
        for (path, remote) in signed {
            playableURLs[path] = await VideoCache.shared.playableURL(for: path, remote: remote)
        }
    }

    private func prefetch(after id: UUID?) {
        guard let id, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let upcoming = profiles.dropFirst(index + 1).prefix(2)
        for profile in upcoming {
            guard let path = profile.videos.first?.storagePath, let url = playableURLs[path], !url.isFileURL else { continue }
            Task { await VideoCache.shared.prefetch(key: path, remote: url) }
        }
    }
}
