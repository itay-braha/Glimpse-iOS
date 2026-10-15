import SwiftUI

/// The mandatory "Filmed N ago" tag shown on every video (when it was filmed,
/// recorded or posted; server-verified for recordings and links).
struct RecencyBadge: View {
    let video: ProfileVideo
    var now: Date = .now
    var compact = false

    private var isStale: Bool { Recency.isStale(video.capturedAt, now: now) }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: video.source.symbolName)
                .imageScale(.small)
            Text(compact ? Recency.shortLabel(video.capturedAt, now: now) : Recency.label(for: video, now: now))
            if !compact {
                Image(systemName: "checkmark.seal.fill")
                    .imageScale(.small)
                    .foregroundStyle(isStale ? Palette.pink : Palette.mint)
                    .accessibilityHidden(true)
            }
        }
        .font(.glimpseCaption)
        .foregroundStyle(isStale ? Palette.pink : Palette.textPrimary)
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(.black.opacity(0.45), in: .capsule)
        .overlay(Capsule().strokeBorder(Palette.textPrimary.opacity(0.12), lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(video.source.displayName), \(Recency.label(for: video, now: now)), verified")
    }
}
