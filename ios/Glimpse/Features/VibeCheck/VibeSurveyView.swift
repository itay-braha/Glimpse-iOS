import SwiftUI

/// Private post-call screen. Neither person ever sees the other's answer;
/// only a mutual "The vibe matched" shows up, as the Vibe Verified badge.
struct VibeSurveyView: View {
    let name: String
    var startReport = false
    let onChoice: (VibeOutcome) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("How was the vibe?")
                .heroFont()
                .foregroundStyle(Palette.textPrimary)
            Text("Only you see this. If you both felt it, your match gets the Vibe Verified badge and a 7-day break from auto-release.")
                .foregroundStyle(Palette.textSecondary)

            Option(symbol: "sparkles", tint: Palette.mint, title: "The vibe matched",
                   detail: "I'd like to meet \(name).") { onChoice(.matched) }
            Option(symbol: "hand.wave.fill", tint: Palette.violet, title: "Friendly, but no romantic chemistry",
                   detail: "No hard feelings, and no effect on anyone's standing.") { onChoice(.friendly) }
            Option(symbol: "exclamationmark.shield.fill", tint: Palette.pink, title: "Report conduct or didn't match their profile",
                   detail: "We'll end the connection and look into it quietly.") { onChoice(.report) }
            Spacer()
        }
        .padding(24)
        .background(Palette.midnight.ignoresSafeArea())
        .onAppear {
            if startReport { onChoice(.report) }
        }
    }
}

private struct Option: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.glimpseHeadline).foregroundStyle(Palette.textPrimary)
                    Text(detail).font(.subheadline).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Palette.surface, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.stroke))
        }
        .buttonStyle(.plain)
    }
}
