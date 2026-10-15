import SwiftUI

/// Keeps text legible over unpredictable video.
struct GradientScrim: View {
    enum Edge {
        case top
        case bottom
    }

    let edge: Edge
    var height: CGFloat = 260
    var strength: Double = 0.75

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(strength), location: 0),
                // Hold most of the darkness through the text band so white type
                // stays legible even over bright, white-background clips.
                .init(color: .black.opacity(strength * 0.85), location: 0.4),
                .init(color: .black.opacity(strength * 0.5), location: 0.7),
                .init(color: .clear, location: 1),
            ],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .frame(height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
