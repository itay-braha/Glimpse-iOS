import Foundation
import Observation

@MainActor
@Observable
final class LikesYouModel {
    private(set) var likes: LikesReceived = .empty
    private(set) var mediaURLs: [String: URL] = [:]
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    var errorMessage: String?
    /// Set after a like-back creates a match, to show the celebration.
    var celebration: MatchCelebration?

    func load(using backend: any GlimpseBackend) async {
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            likes = try await backend.likesReceived()
            await resolveMedia(using: backend)
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    /// Liking back an admirer is always free and always a match.
    func likeBack(_ profile: FeedProfile, using backend: any GlimpseBackend) async {
        do {
            let result = try await backend.swipe(on: profile.id, liked: true)
            if result.matched, let matchID = result.matchID {
                celebration = MatchCelebration(
                    match: MatchSummary(
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
                    ),
                    booted: result.booted
                )
            }
            await load(using: backend)
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    func pass(_ profile: FeedProfile, using backend: any GlimpseBackend) async {
        _ = try? await backend.swipe(on: profile.id, liked: false)
        await load(using: backend)
    }

    private func resolveMedia(using backend: any GlimpseBackend) async {
        let paths = likes.items.compactMap(\.profile).flatMap { $0.videos.compactMap(\.storagePath) }
        guard !paths.isEmpty else { return }
        let signed = await backend.mediaURLs(for: paths)
        for (path, remote) in signed {
            mediaURLs[path] = await VideoCache.shared.playableURL(for: path, remote: remote)
        }
    }
}
