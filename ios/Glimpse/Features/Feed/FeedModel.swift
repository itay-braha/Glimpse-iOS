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
    private var visibleSince = Date.now
    private var isFetchingMore = false

    /// How many profiles ahead are prepared: hosted clips cached, linked posts
    /// checked in the background (dead ones dropped before anyone sees them).
    static let lookahead = 3
    /// Linked-post players warmed ahead (each is a live web view).
    static let embedLookahead = 3

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
            visibleSince = .now
            errorMessage = nil
            prepare(from: 0, using: backend)
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
        if let previous = lastVisibleID, previous != id {
            recordWatch(of: previous)
            if !decidedIDs.contains(previous) {
                decidedIDs.insert(previous)
                Task { _ = try? await backend.swipe(on: previous, liked: false) }
            }
        }
        lastVisibleID = id
        visibleSince = .now

        guard let id, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        prepare(from: index + 1, using: backend)
        // Keep a full look-ahead buffer so the next profiles are always ready.
        if index >= profiles.count - Self.lookahead {
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
        recordWatch(of: profile.id)
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

    /// Glimpse Gold: brings back the last person passed and shows them right here.
    /// Throws `goldRequired` for everyone else.
    func rewind(using backend: any GlimpseBackend) async throws -> Bool {
        guard let person = try await backend.rewindLastPass() else { return false }
        decidedIDs.remove(person.id)
        profiles.removeAll { $0.id == person.id }
        await resolveMedia(for: [person], using: backend)
        let index = currentID.flatMap { id in profiles.firstIndex { $0.id == id } } ?? 0
        profiles.insert(person, at: min(index, profiles.count))
        // Moving back isn't a pass on the card that was showing.
        lastVisibleID = person.id
        visibleSince = .now
        currentID = person.id
        return true
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
        if let current = currentID, let index = profiles.firstIndex(where: { $0.id == current }) {
            prepare(from: index + 1, using: backend)
        }
    }

    /// Watch time on a card: a "view" with its dwell, plus a "rewatch" when it
    /// played well past one loop. Only for real dwell (not a fast flick past).
    private func recordWatch(of id: UUID) {
        let ms = Int(Date.now.timeIntervalSince(visibleSince) * 1000)
        visibleSince = .now
        guard ms >= 700 else { return }
        FeedSignals.shared.record(.view, target: id, dwellMs: min(ms, 600_000))
        let loop = profiles.first { $0.id == id }?.videos.first?.durationSeconds ?? 15
        if Double(ms) > loop * 1000 * 1.6 {
            FeedSignals.shared.record(.rewatch, target: id)
        }
    }

    private func resolveMedia(for batch: [FeedProfile], using backend: any GlimpseBackend) async {
        let paths = batch.flatMap { $0.videos.compactMap(\.storagePath) }
        let signed = await backend.mediaURLs(for: paths)
        for (path, remote) in signed {
            playableURLs[path] = await VideoCache.shared.playableURL(for: path, remote: remote)
        }
    }

    /// Prepares the next profiles: the cover clip of the next 3 and every hosted
    /// clip of the next 2 go into the video cache; linked posts of the next 3 get
    /// a player warmed (and checked) in the background.
    private func prepare(from start: Int, using backend: any GlimpseBackend) {
        guard start < profiles.count else { return }
        let upcoming = profiles[start...].prefix(Self.lookahead)
        for (offset, profile) in upcoming.enumerated() {
            let hosted = profile.videos.filter { !$0.isEmbed }
            for video in offset < 2 ? hosted : Array(hosted.prefix(1)) {
                guard let path = video.storagePath, let url = playableURLs[path], !url.isFileURL else { continue }
                Task { await VideoCache.shared.prefetch(key: path, remote: url) }
            }
            if offset < Self.embedLookahead, !backend.isDemo {
                for video in profile.videos where video.isEmbed {
                    EmbedPrewarmer.shared.warm(video, using: backend)
                }
            }
        }
    }
}
