import SwiftUI

/// The one-time "how to move around" card shown over the first feed.
struct FeedTipsOverlay: View {
    let onDone: () -> Void
    @AppStorage(PlaybackPreferences.clipSecondsKey) private var clipSeconds = PlaybackPreferences.defaultClipSeconds

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("How Glimpse moves")
                    .font(.glimpseTitle2)
                    .foregroundStyle(.white)
                TipRow(symbol: "hand.tap.fill", title: "Tap the sides", detail: "Right for their next clip, left for the previous one.")
                TipRow(symbol: "arrow.up.and.down", title: "Swipe up or down", detail: "Next or previous person.")
                TipRow(symbol: "arrow.left.and.right", title: "Swipe right to like, left to pass", detail: "Or use the buttons on the side.")
                TipRow(symbol: "timer", title: "\(Int(clipSeconds))-second clips", detail: "Each clip plays \(Int(clipSeconds)) s, then the next starts. Tap +more to watch the rest. Change it in Settings.")
                Button("Got it", action: onDone)
                    .buttonStyle(.glimpse)
                    .padding(.top, 6)
                    .accessibilityIdentifier("tips.done")
            }
            .padding(24)
            .background(Palette.surface, in: .rect(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Palette.stroke))
            .padding(24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct TipRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Palette.mint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.glimpseHeadline).foregroundStyle(.white)
                Text(detail).font(.subheadline).foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
