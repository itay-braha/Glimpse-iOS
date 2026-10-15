import Foundation
@testable import Glimpse
import Testing
import UniformTypeIdentifiers

/// The "Let others get a Glimpse of YOU" flows: link parsing (mirrors
/// `private.parse_embed_url`), upload checks and the demo backend contract.
struct VideoFlowTests {
    @Test(arguments: [
        ("https://www.instagram.com/reel/C9xYz_AbC12/?igsh=MWQ1ZGUxMzBkMA==", "https://www.instagram.com/reel/C9xYz_AbC12/"),
        ("https://m.instagram.com/maya.tlv/reels/C9xYz_AbC12", "https://www.instagram.com/reel/C9xYz_AbC12/"),
        ("instagram.com/p/DAbCdEfGhIj/", "https://www.instagram.com/p/DAbCdEfGhIj/"),
        ("  https://www.TikTok.com/@Maya.TLV/video/7301234567890123456?is_from_webapp=1  ",
         "https://www.tiktok.com/@maya.tlv/video/7301234567890123456"),
    ])
    func linksNormalizeToOneCanonicalURL(raw: String, canonical: String) throws {
        let link = try #require(EmbedLink.parse(raw))
        #expect(link.canonicalURL.absoluteString == canonical)
    }

    @Test(arguments: [
        "https://www.youtube.com/shorts/abcdefghijk",
        "https://instagram.com.evil.example/reel/C9xYz_AbC12/",
        "https://www.instagram.com/maya.tlv/",
        "https://www.tiktok.com/@maya.tlv",
        "javascript:alert(1)",
        "",
    ])
    func otherLinksAreRejected(raw: String) {
        #expect(EmbedLink.parse(raw) == nil)
    }

    @Test func playersAreTheOfficialEmbeds() throws {
        let reel = try #require(EmbedLink.parse("https://www.instagram.com/reel/C9xYz_AbC12/"))
        #expect(reel.platform == .instagram)
        #expect(reel.playerURL.absoluteString == "https://www.instagram.com/reel/C9xYz_AbC12/embed/")

        let tiktok = try #require(EmbedLink.parse("https://www.tiktok.com/@maya.tlv/video/7301234567890123456"))
        #expect(tiktok.platform == .tiktok)
        #expect(tiktok.postID == "7301234567890123456")
        #expect(tiktok.playerURL.host() == "www.tiktok.com")
        #expect(tiktok.playerURL.path().hasPrefix("/player/v1/7301234567890123456"))
        #expect(tiktok.playerURL.query()?.contains("muted=1") == true)
    }

    @Test(arguments: [
        "https://www.instagram.com/stories/maya.tlv/3301234567890123456/",
        "instagram.com/stories/highlights/17912345678901234/",
        "https://m.instagram.com/stories/maya.tlv/",
    ])
    func storiesAreRecognizedAndNotLinkable(raw: String) {
        #expect(EmbedLink.isStory(raw))
        #expect(EmbedLink.parse(raw) == nil)
    }

    @Test func postsAreNotStories() {
        #expect(!EmbedLink.isStory("https://www.instagram.com/reel/C9xYz_AbC12/"))
        #expect(!EmbedLink.isStory("https://www.tiktok.com/@maya.tlv/video/7301234567890123456"))
    }

    @Test func unknownNotificationKindsDontBreakTheList() throws {
        let json = Data("""
        [{"id":"00000000-0000-4000-8000-000000000003","kind":"video_unavailable","title":"t","body":"b",
          "created_at":"2026-10-01T10:00:00Z"},
         {"id":"00000000-0000-4000-8000-000000000004","kind":"something_new","title":"t","body":"b",
          "created_at":"2026-10-01T10:00:00Z"}]
        """.utf8)
        let items = try JSONDecoder.glimpse().decode([AppNotification].self, from: json)
        #expect(items.map(\.kind) == [.videoUnavailable, .other])
    }

    @Test func goneLinksAreFlaggedForTheOwner() throws {
        let json = Data("""
        {"id":"00000000-0000-4000-8000-000000000005","source":"tiktok","video_type":"embed",
         "embed_url":"https://www.tiktok.com/@maya.tlv/video/7301234567890123456","moderation_status":"unavailable",
         "captured_at":"2026-10-01T10:00:00Z","imported_at":"2026-10-01T10:00:00Z"}
        """.utf8)
        let video = try JSONDecoder.glimpse().decode(ProfileVideo.self, from: json)
        #expect(video.isUnavailable)
    }

    @Test func postsAreDatedFromTheirLinks() throws {
        let tiktok = try #require(EmbedLink.parse("https://www.tiktok.com/@maya.tlv/video/\(PostIDs.tiktok(daysAgo: 20))"))
        let reel = try #require(EmbedLink.parse("https://www.instagram.com/reel/\(PostIDs.instagram(daysAgo: 45))/"))
        #expect(abs(try #require(tiktok.postDate).timeIntervalSinceNow + 20 * 86_400) < 5)
        #expect(abs(try #require(reel.postDate).timeIntervalSinceNow + 45 * 86_400) < 5)

        // Real-world ids from 2023 and 2024 decode to their actual dates.
        let old = try #require(EmbedLink.parse("https://www.tiktok.com/@maya.tlv/video/7301234567890123456"))
        #expect(Calendar.current.component(.year, from: try #require(old.postDate)) == 2023)
        #expect(Recency.isTooOldToAdd(try #require(old.postDate)))
        let oldReel = try #require(EmbedLink.parse("https://www.instagram.com/reel/C9xYz_AbC12/"))
        #expect(Calendar.current.component(.year, from: try #require(oldReel.postDate)) == 2024)
    }

    @Test func postsOlderThanAYearAreRefused() async throws {
        let backend = DemoBackend(seeded: true)
        let old = try #require(EmbedLink.parse("https://www.tiktok.com/@maya.tlv/video/\(PostIDs.tiktok(daysAgo: 400))"))
        await #expect(throws: GlimpseError.clipTooOld) {
            try await backend.addEmbed(old, promptKey: nil)
        }
        let recent = try #require(EmbedLink.parse("https://www.tiktok.com/@maya.tlv/video/\(PostIDs.tiktok(daysAgo: 100))"))
        let video = try await backend.addEmbed(recent, promptKey: nil)
        #expect(Recency.label(for: video) == "Posted 3 months ago")
    }

    @Test func uploadsFilmedOverAYearAgoAreRefused() async throws {
        let backend = DemoBackend(seeded: true)
        var clip = RecordedClip(fileURL: URL(fileURLWithPath: "/tmp/old.mp4"), durationSeconds: 9, thumbnailJPEG: nil, source: .upload)
        clip.capturedAt = .now.addingTimeInterval(-500 * 86_400)
        await #expect(throws: GlimpseError.clipTooOld) {
            try await backend.uploadClip(clip)
        }
        clip.capturedAt = .now.addingTimeInterval(-60 * 86_400)
        let video = try await backend.uploadClip(clip)
        #expect(Recency.label(for: video) == "Filmed 2 months ago")
    }

    @Test func shortShareLinksAreExpandedFirst() {
        #expect(EmbedLink.needsExpansion("https://vm.tiktok.com/ZMabc123/"))
        #expect(EmbedLink.needsExpansion("https://www.tiktok.com/t/ZTabc123/"))
        #expect(!EmbedLink.needsExpansion("https://www.instagram.com/reel/C9xYz_AbC12/"))
    }

    @Test func rowsWithoutATypeDecodeAsHostedClips() throws {
        let legacy = Data("""
        {"id":"00000000-0000-4000-8000-000000000001","source":"native","storage_path":"u/clip.mp4",
         "duration_seconds":12,"captured_at":"2026-10-01T10:00:00Z","imported_at":"2026-10-01T10:00:00Z"}
        """.utf8)
        let video = try JSONDecoder.glimpse().decode(ProfileVideo.self, from: legacy)
        #expect(video.videoType == .hosted)
        #expect(!video.isEmbed)

        let embed = Data("""
        {"id":"00000000-0000-4000-8000-000000000002","source":"tiktok","video_type":"embed","storage_path":null,
         "embed_url":"https://www.tiktok.com/@maya.tlv/video/7301234567890123456","duration_seconds":null,
         "captured_at":"2026-10-01T10:00:00Z","imported_at":"2026-10-01T10:00:00Z"}
        """.utf8)
        let linked = try JSONDecoder.glimpse().decode(ProfileVideo.self, from: embed)
        #expect(linked.isEmbed)
        #expect(linked.storagePath == nil)
        #expect(linked.embedLink?.platform == .tiktok)
    }

    @Test func onlyMP4AndMOVAreAccepted() {
        #expect(UploadVideoModel.isAccepted([.mpeg4Movie]))
        #expect(UploadVideoModel.isAccepted([.quickTimeMovie]))
        #expect(!UploadVideoModel.isAccepted([.avi]))
        #expect(!UploadVideoModel.isAccepted([.jpeg]))
    }

    @Test func longOrLandscapeClipsGetANote() {
        let landscape = VideoCompressor.Inspection(durationSeconds: 42, size: CGSize(width: 1920, height: 1080))
        #expect(landscape.willTrim)
        #expect(!landscape.isVertical)

        let vertical = VideoCompressor.Inspection(durationSeconds: 14.9, size: CGSize(width: 1080, height: 1920))
        #expect(!vertical.willTrim)
        #expect(vertical.isVertical)
    }

    @Test func demoEmbedsAreAddedOnceWithServerStyleFields() async throws {
        let backend = DemoBackend(seeded: true)
        let link = try #require(EmbedLink.parse("https://www.instagram.com/reel/\(PostIDs.instagram(daysAgo: 30))/?igsh=abc"))
        let video = try await backend.addEmbed(link, promptKey: VibePrompt.quickHello.rawValue)
        #expect(video.isEmbed)
        #expect(video.source == .instagram)
        #expect(video.storagePath == nil)
        #expect(video.embedURL == link.canonicalURL)
        #expect(Recency.label(video.importedAt) == "Added today")

        await #expect(throws: GlimpseError.videoAlreadyAdded) {
            try await backend.addEmbed(link, promptKey: nil)
        }
    }

    @Test func linksNeedAClipOfYourOwnAndSortAfterIt() async throws {
        let backend = DemoBackend(seeded: true, withVideos: false)
        let link = try #require(EmbedLink.parse("https://www.tiktok.com/@maya.tlv/video/\(PostIDs.tiktok(daysAgo: 20))"))
        await #expect(throws: GlimpseError.hostedFirst) {
            try await backend.addEmbed(link, promptKey: nil)
        }

        let clip = RecordedClip(fileURL: URL(fileURLWithPath: "/tmp/a.mp4"), durationSeconds: 10, thumbnailJPEG: nil)
        let own = try await backend.uploadClip(clip)
        let linked = try await backend.addEmbed(link, promptKey: nil)
        #expect(await backend.fetchMyVideos().map(\.id) == [own.id, linked.id])

        await #expect(throws: GlimpseError.lastHostedClip) {
            try await backend.deleteVideo(own)
        }
        try await backend.deleteVideo(linked)
    }

    @Test(arguments: [
        ("This post is unavailable.", true),
        ("Video currently unavailable", true),
        ("Sorry, this content isn't available right now", true),
        ("maya.tlv • Sunrise swim 🌊  View more on Instagram", false),
    ])
    @MainActor
    func unplayablePlayersAreRecognized(text: String, unavailable: Bool) {
        #expect(EmbedHealth.looksUnavailable(text) == unavailable)
    }

    @Test @MainActor func aDeadLinkIsDroppedForThisViewerOnce() {
        let id = UUID()
        let backend = DemoBackend(seeded: true)
        EmbedHealth.shared.markDead(id, using: backend)
        EmbedHealth.shared.markDead(id, using: backend)
        #expect(EmbedHealth.shared.deadForMe.contains(id))
    }

    @Test func uploadsKeepTheirSource() async throws {
        let backend = DemoBackend(seeded: true)
        let clip = RecordedClip(
            fileURL: URL(fileURLWithPath: "/tmp/clip.mp4"), durationSeconds: 15, thumbnailJPEG: nil, source: .upload
        )
        let video = try await backend.uploadClip(clip)
        #expect(video.source == .upload)
        #expect(video.videoType == .hosted)
    }

    @Test func theOnboardingHubStartsWithNoVideos() async throws {
        let backend = DemoBackend(seeded: true, withVideos: false)
        #expect(await backend.fetchMyVideos().isEmpty)
        #expect(await backend.fetchMyProfile()?.isOnboarded == false)
    }
}

/// Post ids for a given age, built the way TikTok and Instagram build them, so
/// tests stay "recent" whenever they run.
enum PostIDs {
    static func tiktok(daysAgo: Double) -> String {
        let seconds = UInt64(Date.now.addingTimeInterval(-daysAgo * 86_400).timeIntervalSince1970)
        return String((seconds << 32) + 777)
    }

    static func instagram(daysAgo: Double) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        let ms = UInt64(Date.now.addingTimeInterval(-daysAgo * 86_400).timeIntervalSince1970 * 1000) - 1_314_220_021_721
        var id = (ms << 23) + 4242
        var code = ""
        for _ in 0..<11 {
            code = String(alphabet[Int(id % 64)]) + code
            id /= 64
        }
        return code
    }
}
