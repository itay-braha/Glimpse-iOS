import AVFoundation
import UIKit

/// On-device compression before upload: re-encodes clips to ~960×540 so a
/// 15-second moment lands around 2–5 MB and streams smoothly over cellular
/// without a server-side transcoding pipeline.
enum VideoCompressor {
    static func prepare(_ sourceURL: URL) async throws -> RecordedClip {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration).seconds

        let outputURL = FileManager.default.temporaryDirectory
            .appending(path: "glimpse-\(UUID().uuidString).mp4")

        let exportedURL: URL
        if let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset960x540) {
            session.shouldOptimizeForNetworkUse = true
            try await session.export(to: outputURL, as: .mp4)
            exportedURL = outputURL
        } else {
            exportedURL = sourceURL
        }

        return RecordedClip(
            fileURL: exportedURL,
            durationSeconds: min(duration, 15),
            thumbnailJPEG: await thumbnail(for: AVURLAsset(url: exportedURL))
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
