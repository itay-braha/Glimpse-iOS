import SwiftUI

/// The glowing "Me" ring that points out the profile owner in group clips.
/// The position is normalized to the full-bleed (aspect-filled) frame.
struct MeMarkerRing: View {
    var diameter: CGFloat = 86
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .strokeBorder(Palette.brandGradient, lineWidth: 4)
                .frame(width: diameter, height: diameter)
                .shadow(color: Palette.pink.opacity(0.8), radius: 12)
                .scaleEffect(pulse ? 1.08 : 0.94)
            Text("Me")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Palette.onMint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Palette.mint, in: .capsule)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Marked as the person in this profile")
    }
}
