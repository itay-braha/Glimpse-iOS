import SwiftUI

/// The vibe prompt shown over a clip: an instant conversation starter.
struct PromptSticker: View {
    let prompt: VibePrompt

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "quote.opening")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Palette.brandGradient)
            Text(prompt.text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.5), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.violet.opacity(0.6), lineWidth: 1))
        .accessibilityLabel("Prompt: \(prompt.text)")
    }
}
