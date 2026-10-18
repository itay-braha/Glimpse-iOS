@preconcurrency import AVFoundation
import Observation
import SwiftUI

/// One voice message plays at a time across the chat.
@MainActor
@Observable
final class VoicePlayback {
    static let shared = VoicePlayback()

    private(set) var playingID: UUID?
    private(set) var progress: Double = 0
    private var player: AVPlayer?
    private var observer: Any?

    private init() {}

    func toggle(_ id: UUID, url: URL, duration: Double) {
        if playingID == id {
            stop()
            return
        }
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let player = AVPlayer(url: url)
        self.player = player
        playingID = id
        progress = 0
        let total = max(duration, 0.1)
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.progress = min(time.seconds / total, 1)
                if self.progress >= 0.999 { self.stop() }
            }
        }
        player.play()
    }

    func stop() {
        if let observer, let player { player.removeTimeObserver(observer) }
        observer = nil
        player?.pause()
        player = nil
        playingID = nil
        progress = 0
    }
}

/// A voice message: play/pause, progress and length.
struct VoiceNoteBubble: View {
    let message: ChatMessage
    let url: URL?
    let isMine: Bool

    @State private var playback = VoicePlayback.shared

    private var isPlaying: Bool { playback.playingID == message.id }
    private var duration: Double { message.mediaDuration ?? 0 }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if let url { playback.toggle(message.id, url: url, duration: duration) }
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isMine ? Palette.mint : Palette.onMint)
                    .frame(width: 36, height: 36)
                    .background(isMine ? Palette.onMint : Palette.mint, in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(url == nil)
            .accessibilityLabel(isPlaying ? "Pause voice message" : "Play voice message")

            WaveformBar(progress: isPlaying ? playback.progress : 0, seed: message.id.hashValue, tint: isMine ? Palette.onMint : Palette.textPrimary)
                .frame(width: 120, height: 26)
                .accessibilityHidden(true)

            Text(Self.format(duration))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(isMine ? Palette.onMint.opacity(0.8) : Palette.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bubble.voice")
    }

    static func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Bars that fill as the message plays (a stand-in shape, not the real waveform).
private struct WaveformBar: View {
    let progress: Double
    let seed: Int
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let count = 24
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<count, id: \.self) { index in
                    let height = 0.3 + 0.7 * abs(sin(Double(index * 7 + seed % 97) * 0.9))
                    Capsule()
                        .fill(Double(index) / Double(count) <= progress ? tint : tint.opacity(0.35))
                        .frame(width: max((proxy.size.width - CGFloat(count - 1) * 2) / CGFloat(count), 1),
                               height: proxy.size.height * height)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

/// A round selfie video note: plays silently on a loop; tap for sound from the start.
struct VideoNoteBubble: View {
    let message: ChatMessage
    let url: URL?

    @State private var withSound = false
    @State private var playToken = 0

    var body: some View {
        ZStack {
            Palette.surfaceRaised
            if let url {
                LoopingVideoPlayer(url: url, isActive: true, isMuted: !withSound)
                    .id("\(message.id)-\(playToken)")
                    .allowsHitTesting(false)
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(width: 200, height: 200)
        .clipShape(.circle)
        .overlay(Circle().strokeBorder(Palette.mint.opacity(0.6), lineWidth: 2))
        .overlay(alignment: .bottom) {
            HStack(spacing: 4) {
                Image(systemName: withSound ? "speaker.wave.2.fill" : "speaker.slash.fill")
                Text(VoiceNoteBubble.format(message.mediaDuration ?? 0))
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45), in: .capsule)
            .padding(.bottom, 12)
        }
        .contentShape(.circle)
        .onTapGesture {
            withSound.toggle()
            if withSound { playToken += 1 } // start over with sound
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Video message, \(VoiceNoteBubble.format(message.mediaDuration ?? 0))")
        .accessibilityHint(withSound ? "Tap to mute" : "Tap to play with sound")
        .accessibilityIdentifier("bubble.video")
    }
}
