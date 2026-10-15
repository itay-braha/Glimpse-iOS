import Foundation
import Observation

@MainActor
@Observable
final class ProfileModel {
    static let maxVideos = 6

    private(set) var videos: [ProfileVideo] = []
    private(set) var mediaURLs: [String: URL] = [:]
    private(set) var isImporting = false
    var errorMessage: String?

    var staleVideos: [ProfileVideo] { videos.filter { Recency.isStale($0.importedAt) } }
    var canAddVideo: Bool { videos.count < Self.maxVideos }

    func load(using backend: any GlimpseBackend) async {
        do {
            let fresh = try await backend.fetchMyVideos()
            await resolveMedia(for: fresh, using: backend)
            videos = fresh
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    func added(_ video: ProfileVideo, using backend: any GlimpseBackend) async {
        await resolveMedia(for: [video], using: backend)
        videos.insert(video, at: 0)
    }

    func delete(_ video: ProfileVideo, using backend: any GlimpseBackend) async {
        guard videos.count > 1 else {
            errorMessage = "Keep at least one moment on your profile."
            return
        }
        do {
            try await backend.deleteVideo(video)
            videos.removeAll { $0.id == video.id }
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    func updateDetails(_ video: ProfileVideo, prompt: VibePrompt?, marker: CGPoint?, using backend: any GlimpseBackend) async {
        do {
            try await backend.updateVideoDetails(video.id, promptKey: prompt?.rawValue, meMarker: marker)
            if let index = videos.firstIndex(where: { $0.id == video.id }) {
                videos[index].promptKey = prompt?.rawValue
                videos[index].meMarkerX = marker.map { Double($0.x) }
                videos[index].meMarkerY = marker.map { Double($0.y) }
            }
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    /// Moves a clip to the front; the first clip is the cover people see first.
    func makeCover(_ video: ProfileVideo, using backend: any GlimpseBackend) async {
        guard let index = videos.firstIndex(of: video), index > 0 else { return }
        let previous = videos
        videos.remove(at: index)
        videos.insert(video, at: 0)
        do {
            try await backend.reorderVideos(videos.map(\.id))
        } catch {
            videos = previous
            errorMessage = GlimpseError.describe(error)
        }
    }

    func importInstagram(using backend: any GlimpseBackend, config: AppConfig?) async {
        isImporting = true
        defer { isImporting = false }
        do {
            let imported = try await InstagramImporter.run(backend: backend, config: config)
            if imported.isEmpty {
                errorMessage = "No Reels from the last 90 days were found."
            }
            await load(using: backend)
        } catch InstagramImporter.Failure.cancelled {
            return
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    func url(for path: String?) -> URL? {
        path.flatMap { mediaURLs[$0] }
    }

    private func resolveMedia(for batch: [ProfileVideo], using backend: any GlimpseBackend) async {
        let paths = batch.flatMap { [$0.storagePath, $0.thumbnailPath].compactMap { $0 } }
        guard !paths.isEmpty else { return }
        mediaURLs.merge(await backend.mediaURLs(for: paths)) { _, new in new }
    }
}
