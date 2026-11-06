import SwiftUI

/// One box in a row of digits (phone number, SMS code). A typed digit springs in,
/// the box waiting for the next digit glows mint with a blinking caret, and a
/// deleted digit shrinks away.
struct DigitSlot: View {
    let digit: Character?
    let isActive: Bool
    var height: CGFloat = 58

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isFilled: Bool { digit != nil }

    var body: some View {
        ZStack {
            if let digit {
                Text(String(digit))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .transition(digitTransition)
            } else if isActive {
                Caret()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(isFilled ? Palette.mint.opacity(0.07) : Palette.surfaceRaised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: isActive ? 2 : 1)
        }
        .shadow(color: isActive ? Palette.mint.opacity(0.35) : .clear, radius: 8)
        .scaleEffect(isActive && !reduceMotion ? 1.06 : 1)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.6), value: digit)
        .animation(.snappy(duration: 0.2), value: isActive)
    }

    private var digitTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let insertion = AnyTransition.scale(scale: 0.3)
            .combined(with: .opacity)
            .combined(with: .offset(y: 10))
        let removal = AnyTransition.scale(scale: 0.6).combined(with: .opacity)
        return .asymmetric(insertion: insertion, removal: removal)
    }

    private var borderColor: Color {
        if isActive { return Palette.mint }
        return isFilled ? Palette.mint.opacity(0.35) : Palette.stroke
    }
}

/// The blinking text cursor inside the active slot.
private struct Caret: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            bar
        } else {
            bar.phaseAnimator([1.0, 0.15]) { content, opacity in
                content.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 0.55)
            }
        }
    }

    private var bar: some View {
        Capsule()
            .fill(Palette.mint)
            .frame(width: 2.5, height: 26)
    }
}

extension View {
    /// Shakes sideways each time `trigger` changes (a rejected code).
    func shake(trigger: Int) -> some View {
        keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-12, duration: 0.06)
                LinearKeyframe(10, duration: 0.08)
                LinearKeyframe(-7, duration: 0.08)
                LinearKeyframe(4, duration: 0.07)
                SpringKeyframe(0, duration: 0.2)
            }
        }
    }
}
