import SwiftUI

struct TypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Palette.textSecondary)
                        .frame(width: 7, height: 7)
                        .offset(y: reduceMotion ? 0 : -3 * sin(t * 6 - Double(index) * 0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Palette.surfaceRaised, in: .capsule)
        }
        .accessibilityLabel("Typing")
    }
}
