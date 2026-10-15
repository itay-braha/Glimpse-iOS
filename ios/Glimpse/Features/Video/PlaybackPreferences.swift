import Observation
import SwiftUI

/// Clips start muted. One tap on the speaker unmutes every clip for the rest of
/// the session, so people don't have to unmute each profile.
@MainActor
@Observable
final class PlaybackPreferences {
    static let shared = PlaybackPreferences()

    /// How long each clip plays in the feed before moving to the next (Settings, 5–15 s).
    nonisolated static let clipSecondsKey = "glimpse.clipSeconds"
    nonisolated static let defaultClipSeconds = 7.0
    nonisolated static let clipSecondsRange: ClosedRange<Double> = 5...15

    var isMuted = true

    private init() {}
}

/// Speaker toggle for hosted clips (embeds bring their own controls).
struct MuteToggle: View {
    var size: CGFloat = 44
    @State private var preferences = PlaybackPreferences.shared

    var body: some View {
        Button {
            preferences.isMuted.toggle()
        } label: {
            Image(systemName: preferences.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: size, height: size)
                .background(.black.opacity(0.35), in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preferences.isMuted ? "Unmute" : "Mute")
        .accessibilityIdentifier("muteToggle")
        .sensoryFeedback(.selection, trigger: preferences.isMuted)
    }
}
