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
        let link = try #require(EmbedLink.parse("https://www.instagram.com/reel/C9xYz_AbC12/?igsh=abc"))
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
