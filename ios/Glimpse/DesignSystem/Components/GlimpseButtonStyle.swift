import SwiftUI

struct GlimpseButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
    }

    var kind: Kind = .primary

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.glimpseHeadline)
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 20)
            .foregroundStyle(foreground)
            .background(background, in: .capsule)
            .overlay {
                if kind == .secondary {
                    Capsule().strokeBorder(Palette.textPrimary.opacity(0.4), lineWidth: 1.5)
                }
            }
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: Palette.onMint
        case .secondary: Palette.textPrimary
        case .destructive: .white
        }
    }

    private var background: Color {
        switch kind {
        case .primary: Palette.mint
        case .secondary: Palette.surfaceRaised
        case .destructive: Palette.pink
        }
    }
}

extension ButtonStyle where Self == GlimpseButtonStyle {
    static var glimpse: GlimpseButtonStyle { GlimpseButtonStyle() }
    static var glimpseSecondary: GlimpseButtonStyle { GlimpseButtonStyle(kind: .secondary) }
    static var glimpseDestructive: GlimpseButtonStyle { GlimpseButtonStyle(kind: .destructive) }
}
