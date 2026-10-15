import SwiftUI

/// "Glimpse" set like the logo: a heavier "Gli", lighter "mpse", silver fill,
/// optionally led by the heart-play mark.
struct Wordmark: View {
    var size: CGFloat = 28
    var showsMark = true

    var body: some View {
        HStack(spacing: size * 0.28) {
            if showsMark {
                LogoMark(size: size * 1.15, glow: size > 30)
            }
            (Text("Gli").fontWeight(.heavy) + Text("mpse").fontWeight(.medium))
                .font(.system(size: size, design: .default))
                .kerning(-0.3)
                .foregroundStyle(Palette.silverGradient)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Glimpse")
    }
}
