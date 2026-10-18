import SwiftUI

/// Shown when someone tries to like with none left: clear that they're out, when
/// more arrive, what's still free, and Glimpse Gold for while they wait.
struct OutOfLikesSheet: View {
    let resetsAt: Date?
    let admirers: Int
    let onSeeAdmirers: () -> Void
    let onSeeGold: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 46))
                .foregroundStyle(Palette.pink)
                .padding(.top, 10)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("You're out of likes for today")
                    .font(.glimpseTitle2)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                if let resetsAt {
                    // Ticks down live while the sheet is open.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("New likes in \(Self.countdown(to: resetsAt, now: context.date))")
                            .font(.glimpseHeadline)
                            .monospacedDigit()
                            .foregroundStyle(Palette.mint)
                    }
                    .accessibilityIdentifier("outOfLikes.countdown")
                }
                Text("Everyone gets 10 likes a day, so each one means something. Passing, and liking back someone who already liked you, are always free.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if admirers > 0 {
                Button {
                    dismiss()
                    onSeeAdmirers()
                } label: {
                    Label(admirers == 1 ? "1 person already liked you" : "\(admirers) people already liked you",
                          systemImage: "heart.circle.fill")
                }
                .buttonStyle(.glimpse)
                .accessibilityIdentifier("outOfLikes.admirers")
            }

            Button {
                dismiss()
                onSeeGold()
            } label: {
                VStack(spacing: 2) {
                    Label("While you wait: Glimpse Gold", systemImage: "crown.fill")
                        .font(.glimpseHeadline)
                    Text("Spotlight, Rewind, Travel mode and clip insights")
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(Palette.amber)
                .background(Palette.surface, in: .rect(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.amber.opacity(0.6)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("outOfLikes.gold")

            Button("Keep browsing") { dismiss() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(24)
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.midnight)
        .accessibilityIdentifier("outOfLikes")
    }

    static func countdown(to date: Date, now: Date) -> String {
        let seconds = max(Int(date.timeIntervalSince(now)), 0)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m \(seconds % 60)s"
    }
}
