import SwiftUI

/// Shared layout for onboarding steps: back button, title block, content, pinned footer.
struct OnboardingScaffold<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String
    var onBack: (() -> Void)?
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onBack {
                Button("Back", systemImage: "chevron.left", action: onBack)
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Palette.surfaceRaised, in: .circle)
                    .padding(.bottom, 20)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(title)
                        .font(.glimpseTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text(subtitle)
                        .font(.glimpseBody)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 10)
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)

            footer
                .padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Palette.midnight.ignoresSafeArea())
    }
}

struct ErrorText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "exclamationmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Palette.pink)
    }
}

struct DemoHint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: "sparkles")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Palette.mint)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.mint.opacity(0.1), in: .rect(cornerRadius: 12))
    }
}
