import SwiftUI

/// Glimpse color tokens, matched to the logo. Dark-first: a deep midnight canvas
/// so video pops, neon mint for "go" actions, cyber pink for the match moment and
/// capacity pressure, violet bridging the two in the brand gradient.
enum Palette {
    static let midnight = Color(hex: 0x090D16)
    static let surface = Color(hex: 0x111827)
    static let surfaceRaised = Color(hex: 0x1A2333)
    static let stroke = Color.white.opacity(0.08)

    static let mint = Color(hex: 0x3DFFB8)
    static let pink = Color(hex: 0xFF3DB8)
    static let violet = Color(hex: 0x9B5CFF)
    static let amber = Color(hex: 0xFFC24B)

    /// Brushed-silver fill for the wordmark.
    static var silverGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xFFFFFF), Color(hex: 0xC9CFDB)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static let textPrimary = Color(hex: 0xF4F6FB)
    static let textSecondary = Color(hex: 0x9AA4B8)
    static let textTertiary = Color(hex: 0x5D6679)
    static let onMint = Color(hex: 0x04140D)

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [pink, violet, mint],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// A stable, pleasant two-stop gradient derived from a seed string (names, ids).
    static func seededGradient(_ seed: String) -> LinearGradient {
        let hue = Double(seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } % 360) / 360
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.65, brightness: 0.55),
                Color(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 0.25),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
