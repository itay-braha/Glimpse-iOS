import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    @State private var acceptsTerms = false
    @State private var acceptsSensitiveData = false

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Wordmark(size: 34)
                    .padding(.top, 24)
                    .padding(.bottom, 28)

                Text("Real moments.\nReal people.")
                    .heroFont()
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Dating built around your safety.")
                    .font(.title3)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 18) {
                    ValueProp(symbol: "play.rectangle.fill", tint: Palette.mint,
                              title: "Video-first", detail: "Your Reels and real moments, not studio shots.")
                    ValueProp(symbol: "circle.dashed", tint: Palette.pink,
                              title: "15 connections, max", detail: "Quiet chats make room for new ones.")
                    ValueProp(symbol: "checkmark.shield.fill", tint: Color(hex: 0x7AF0FF),
                              title: "Safety first", detail: "Real numbers, real devices. Reports are handled right away.")
                    ValueProp(symbol: "eye.slash.fill", tint: Palette.violet,
                              title: "Private by design", detail: "No screen recording anywhere in Glimpse, and no screenshots during Vibe Checks.")
                }
                .padding(.vertical, 28)

                ConsentToggles(acceptsTerms: $acceptsTerms, acceptsSensitiveData: $acceptsSensitiveData)
                    .padding(.bottom, 14)
            }
            .padding(.horizontal, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                Button("Get started") {
                    ConsentStore.markPending()
                    onStart()
                }
                .buttonStyle(.glimpse)
                .disabled(!acceptsTerms || !acceptsSensitiveData)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
        }
    }
}

private struct ValueProp: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).font(.glimpseHeadline)
                Text(LocalizedStringKey(detail))
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView {}
}
