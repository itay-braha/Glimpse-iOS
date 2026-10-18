import AVFoundation
import SwiftUI

/// Full-bleed, seamlessly looping video. SwiftUI's `VideoPlayer` brings its own
/// chrome and can't aspect-fill, so this wraps an `AVPlayerLayer` directly.
/// Other people's videos play inside a `SecureCanvas`, so screenshots and screen
/// recordings of them come out blank. `protected: false` is for your own recordings.
struct LoopingVideoPlayer: UIViewRepresentable {
    let url: URL
    var isActive: Bool
    var isMuted = false
    var protected = true

    func makeUIView(context: Context) -> SecureCanvas {
        let canvas = SecureCanvas(frame: .zero, protect: protected && SecureCanvas.protectsMedia)
        let player = PlayerView()
        canvas.embed(player)
        context.coordinator.player = player
        return canvas
    }

    func updateUIView(_ canvas: SecureCanvas, context: Context) {
        guard let view = context.coordinator.player else { return }
        view.load(url)
        view.player.isMuted = isMuted
        view.setPlaying(isActive)
    }

    static func dismantleUIView(_ canvas: SecureCanvas, coordinator: Coordinator) {
        coordinator.player?.teardown()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        var player: PlayerView?
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }

        let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private var currentURL: URL?

        private var playerLayer: AVPlayerLayer {
            // swiftlint:disable:next force_cast
            layer as! AVPlayerLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            player.preventsDisplaySleepDuringVideoPlayback = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        func load(_ url: URL) {
            guard url != currentURL else { return }
            currentURL = url
            looper?.disableLooping()
            player.removeAllItems()
            let item = AVPlayerItem(url: url)
            item.preferredForwardBufferDuration = 3
            looper = AVPlayerLooper(player: player, templateItem: item)
        }

        func setPlaying(_ playing: Bool) {
            if playing {
                if player.timeControlStatus != .playing { player.play() }
            } else {
                player.pause()
            }
        }

        func teardown() {
            player.pause()
            looper?.disableLooping()
            looper = nil
            player.removeAllItems()
        }
    }
}
