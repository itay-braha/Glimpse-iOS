import SwiftUI

struct MatchCelebrationView: View {
    let celebration: MatchCelebration
    let myName: String
    let onMessage: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AuroraBackground()
                .opacity(0.9)
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                HStack(spacing: -22) {
                    AvatarView(name: myName, size: 112, ringColor: Palette.mint)
                        .rotationEffect(.degrees(appeared ? -8 : 0))
                    AvatarView(name: celebration.match.displayName, size: 112, ringColor: Palette.pink)
                        .rotationEffect(.degrees(appeared ? 8 : 0))
                }
                .scaleEffect(appeared || reduceMotion ? 1 : 0.6)

                VStack(spacing: 10) {
                    Text("It's a Glimpse")
                        .heroFont()
                        .foregroundStyle(Palette.brandGradient)
                    Text("You and \(celebration.match.displayName) both want to see more.")
                        .font(.title3)
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.center)
                }

                if let booted = celebration.booted {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title3)
                            .foregroundStyle(Palette.pink)
                        Text("To keep your circle at 20, your quietest connection with **\(booted.displayName)** was released.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .padding(16)
                    .background(Palette.surface.opacity(0.85), in: .rect(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.pink.opacity(0.4)))
                }

                Spacer()

                VStack(spacing: 12) {
                    Button("Send a message", action: onMessage)
                        .buttonStyle(.glimpse)
                    Button("Keep exploring", action: onDismiss)
                        .buttonStyle(.glimpseSecondary)
                }
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.45)) { appeared = true }
        }
        .sensoryFeedback(.success, trigger: appeared)
    }
}
