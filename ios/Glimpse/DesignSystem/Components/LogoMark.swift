import SwiftUI

/// The Glimpse mark: a heart drawn as one ribbon around a play button,
/// pink → violet → mint like the brand logo.
struct LogoMark: View {
    var size: CGFloat = 44
    var glow = true

    var body: some View {
        let stroke = StrokeStyle(lineWidth: size * 0.11, lineCap: .round, lineJoin: .round)
        ZStack {
            HeartShape().stroke(Palette.brandGradient, style: stroke)
            PlayShape().stroke(Palette.brandGradient, style: stroke)
        }
        .frame(width: size, height: size)
        .shadow(color: glow ? Palette.violet.opacity(0.55) : .clear, radius: size * 0.18)
        .accessibilityHidden(true)
    }
}

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY
        var path = Path()
        path.move(to: CGPoint(x: x + w * 0.5, y: y + h * 0.9))
        path.addCurve(
            to: CGPoint(x: x + w * 0.04, y: y + h * 0.32),
            control1: CGPoint(x: x + w * 0.18, y: y + h * 0.68),
            control2: CGPoint(x: x + w * 0.04, y: y + h * 0.52)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.5, y: y + h * 0.2),
            control1: CGPoint(x: x + w * 0.04, y: y + h * 0.04),
            control2: CGPoint(x: x + w * 0.4, y: y)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.96, y: y + h * 0.32),
            control1: CGPoint(x: x + w * 0.6, y: y),
            control2: CGPoint(x: x + w * 0.96, y: y + h * 0.04)
        )
        path.addCurve(
            to: CGPoint(x: x + w * 0.5, y: y + h * 0.9),
            control1: CGPoint(x: x + w * 0.96, y: y + h * 0.52),
            control2: CGPoint(x: x + w * 0.82, y: y + h * 0.68)
        )
        path.closeSubpath()
        return path
    }
}

struct PlayShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + w * 0.4, y: rect.minY + h * 0.33))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.4, y: rect.minY + h * 0.63))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.65, y: rect.minY + h * 0.48))
        path.closeSubpath()
        return path
    }
}

#Preview {
    LogoMark(size: 160)
        .padding(40)
        .background(Palette.midnight)
}
