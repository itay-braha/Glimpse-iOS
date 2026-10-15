import AVFoundation
import UIKit

/// Exports a profile clip as a shareable vertical video with a Glimpse
/// watermark and a caption ("Itay, 28 · Tel Aviv"), for TikTok/Reels/Stories.
enum VideoWatermarker {
    static func export(_ source: URL, caption: String) async throws -> URL {
        let local = try await localCopy(of: source)
        let asset = AVURLAsset(url: local)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw GlimpseError.message("That clip can't be exported.")
        }
        let natural = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let oriented = natural.applying(transform)
        let renderSize = CGSize(width: abs(oriented.width), height: abs(oriented.height))

        let composition = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: asset)
        composition.renderSize = renderSize

        let parent = CALayer()
        parent.frame = CGRect(origin: .zero, size: renderSize)
        let videoLayer = CALayer()
        videoLayer.frame = parent.frame
        parent.addSublayer(videoLayer)
        parent.addSublayer(watermark(caption: caption, in: renderSize))
        composition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer, in: parent
        )

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw GlimpseError.message("Export isn't available on this device.")
        }
        session.videoComposition = composition
        let output = FileManager.default.temporaryDirectory.appending(path: "glimpse-share-\(UUID().uuidString).mp4")
        try await session.export(to: output, as: .mp4)
        return output
    }

    private static func localCopy(of url: URL) async throws -> URL {
        if url.isFileURL { return url }
        let (temp, _) = try await URLSession.shared.download(from: url)
        let destination = FileManager.default.temporaryDirectory.appending(path: "glimpse-src-\(UUID().uuidString).mp4")
        try FileManager.default.moveItem(at: temp, to: destination)
        return destination
    }

    /// Core Animation's video coordinates start at the bottom-left.
    private static func watermark(caption: String, in size: CGSize) -> CALayer {
        let unit = size.width / 24
        let container = CALayer()
        container.frame = CGRect(x: unit, y: unit * 1.5, width: size.width - unit * 2, height: unit * 4.5)

        let backdrop = CALayer()
        backdrop.frame = container.bounds
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.45).cgColor
        backdrop.cornerRadius = unit
        container.addSublayer(backdrop)

        let brand = CATextLayer()
        brand.string = "glimpse"
        brand.font = UIFont.systemFont(ofSize: unit * 1.6, weight: .black)
        brand.fontSize = unit * 1.6
        brand.foregroundColor = UIColor(red: 0.24, green: 1, blue: 0.72, alpha: 1).cgColor
        brand.frame = CGRect(x: unit, y: unit * 2.2, width: container.bounds.width - unit * 2, height: unit * 2)
        brand.contentsScale = 2

        let line = CATextLayer()
        line.string = "\(caption) · find me on Glimpse"
        line.font = UIFont.systemFont(ofSize: unit, weight: .semibold)
        line.fontSize = unit
        line.foregroundColor = UIColor.white.cgColor
        line.frame = CGRect(x: unit, y: unit * 0.7, width: container.bounds.width - unit * 2, height: unit * 1.4)
        line.contentsScale = 2
        line.truncationMode = .end

        container.addSublayer(brand)
        container.addSublayer(line)
        return container
    }
}
