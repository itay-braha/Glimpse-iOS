import SwiftUI

/// Soft mint/pink glows drifting behind brand screens.
struct AuroraBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Palette.midnight
                    glow(Palette.mint, diameter: size.width * 1.1)
                        .offset(x: -size.width * 0.35 + sin(t / 4) * 30, y: -size.height * 0.28 + cos(t / 5) * 40)
                    glow(Palette.pink, diameter: size.width * 1.0)
                        .offset(x: size.width * 0.4 + cos(t / 6) * 30, y: size.height * 0.05 + sin(t / 4.5) * 50)
                    glow(Color(hex: 0x6A5CFF), diameter: size.width * 0.9)
                        .offset(x: -size.width * 0.1 + sin(t / 7) * 40, y: size.height * 0.42)
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func glow(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.32))
            .frame(width: diameter, height: diameter)
            .blur(radius: diameter * 0.28)
    }
}
