import SwiftUI

/// A small, polite, in-context offer to turn on one kind of alert. Three ways
/// out: yes, not now, or don't ask about this again.
struct AlertNudgeSheet: View {
    let nudge: AlertNudge
    let onAnswer: (_ accepted: Bool, _ never: Bool) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: nudge.symbol)
                .font(.system(size: 40))
                .foregroundStyle(Palette.brandGradient)
                .padding(.top, 8)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(nudge.title)
                    .font(.glimpseTitle2)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                Text(nudge.message)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Yes, let me know") { onAnswer(true, false) }
                .buttonStyle(.glimpse)
                .accessibilityIdentifier("nudge.yes")
            HStack {
                Button("Not now") { onAnswer(false, false) }
                    .accessibilityIdentifier("nudge.notNow")
                Spacer()
                Button("Don't ask again") { onAnswer(false, true) }
                    .accessibilityIdentifier("nudge.never")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.textSecondary)
        }
        .padding(24)
        .presentationDetents([.height(400)])
        .presentationBackground(Palette.midnight)
        // A container, so the buttons keep their own identifiers.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("nudge.\(nudge.topic.rawValue)")
    }
}
