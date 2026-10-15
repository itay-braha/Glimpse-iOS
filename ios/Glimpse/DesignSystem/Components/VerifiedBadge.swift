import SwiftUI

/// Shown on profiles that passed the selfie-video check.
struct VerifiedBadge: View {
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: "checkmark.seal.fill")
            .font(.system(size: size))
            .symbolRenderingMode(.palette)
            .foregroundStyle(Palette.midnight, Palette.mint)
            .accessibilityLabel("Verified")
    }
}
