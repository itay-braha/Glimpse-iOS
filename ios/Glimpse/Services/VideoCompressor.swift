import AVFoundation
import UIKit

/// On-device compression before upload: re-encodes clips to ~960×540 so a
/// 15-second moment lands around 2–5 MB and streams smoothly over cellular
/// without a server-side transcoding pipeline. Camera-roll videos are trimmed to
/// their first 15 seconds here too.
enum VideoCompressor {
    static let maxDuration: Double = 15
    static let maxBytes = 20 * 1024 * 1024

    /// What we know about a picked video before compressing it.
    struct Inspection: Equatable, Sendable {
        let durationSeconds: Double
        /// Display size after the track's rotation is applied.
        let size: CGSize
        /// When it was filmed, from the file's metadata (nil when the file doesn't say).
        var filmedAt: Date?

        var isPortrait: Bool { size.height > size.width }
        /// 9:16 give or take (covers 3:4-ish phone crops too).
        var isVertical: Bool { size.width > 0 && size.height / size.width >= 1.3 }
        var willTrim: Bool { durationSeconds > VideoCompressor.maxDuration + 0.5 }
    }

    static func inspect(_ url: URL) async throws -> Inspection {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw GlimpseError.message("That file has no video in it.")
        }
        let (natural, transform) = try await track.load(.naturalSize, .preferredTransform)
        let rect = CGRect(origin: .zero, size: natural).applying(transform)
        var filmedAt: Date?
        if let item = try? await asset.load(.creationDate) {
            filmedAt = try? await item.load(.dateValue)
        }
        return Inspection(
            durationSeconds: duration,
            size: CGSize(width: abs(rect.width), height: abs(rect.height)),
            filmedAt: filmedAt
        )
    }

    static func prepare(_ sourceURL: URL, source: VideoSource = .native, filmedAt: Date? = nil) async throws -> RecordedClip {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration).seconds
        let kept = min(duration, maxDuration)

        let outputURL = FileManager.default.temporaryDirectory
            .appending(path: "glimpse-\(UUID().uuidString).mp4")

        let exportedURL: URL
        if let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset960x540) {
            session.shouldOptimizeForNetworkUse = true
            session.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: kept, preferredTimescale: 600))
            try await session.export(to: outputURL, as: .mp4)
            exportedURL = outputURL
        } else {
            exportedURL = sourceURL
        }

        let bytes = (try? exportedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard bytes <= maxBytes else { throw GlimpseError.videoTooLarge }

        return RecordedClip(
            fileURL: exportedURL,
            durationSeconds: kept,
            thumbnailJPEG: await thumbnail(for: AVURLAsset(url: exportedURL)),
            source: source,
            byteCount: bytes,
            capturedAt: filmedAt
        )
    }

    static func thumbnail(for asset: AVAsset) async -> Data? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 540, height: 960)
        guard let frame = try? await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)) else {
            return nil
        }
        return UIImage(cgImage: frame.image).jpegData(compressionQuality: 0.72)
    }
}
