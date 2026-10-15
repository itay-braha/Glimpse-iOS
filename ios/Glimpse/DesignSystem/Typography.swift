import SwiftUI

/// Rounded, heavy display type for brand moments; system text styles everywhere else
/// so Dynamic Type keeps working.
extension Font {
    static let glimpseTitle = Font.system(.title, design: .rounded, weight: .heavy)
    static let glimpseTitle2 = Font.system(.title2, design: .rounded, weight: .bold)
    static let glimpseHeadline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let glimpseBody = Font.system(.body, design: .default)
    static let glimpseCaption = Font.system(.caption, design: .rounded, weight: .semibold)
}

/// The big brand headline. Scales with Dynamic Type (a fixed-size system font wouldn't).
private struct HeroFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 44

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .black, design: .rounded))
    }
}

extension View {
    func heroFont() -> some View {
        modifier(HeroFont())
    }
}
