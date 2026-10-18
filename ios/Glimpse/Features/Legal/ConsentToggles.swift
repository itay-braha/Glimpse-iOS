import SwiftUI

/// The two required agreements, as explicit switches (not "by continuing you agree"):
/// 18+ and the terms, and consent to processing sensitive details to provide the service.
struct ConsentToggles: View {
    @Binding var acceptsTerms: Bool
    @Binding var acceptsSensitiveData: Bool
    @State private var legal: LegalDocument?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $acceptsTerms) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("I'm 18 or older and I agree to the Terms of Service, Privacy Policy and Community Rules.")
                        .font(.footnote)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        Button("Terms") { legal = .terms }
                        Button("Privacy Policy") { legal = .privacy }
                        Button("Community Rules") { legal = .communityRules }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.mint)
                    .buttonStyle(.plain)
                }
            }
            .accessibilityIdentifier("consent.terms")

            Toggle(isOn: $acceptsSensitiveData) {
                Text("I agree that Glimpse processes my profile, including my gender, who I'm interested in and my approximate location, to show me matches.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("consent.sensitive")
        }
        .tint(Palette.mint)
        .sheet(item: $legal) { document in
            LegalDocumentView(document: document)
        }
    }
}

/// Shown once after the Terms or Privacy Policy change; Glimpse can't be used until accepted.
struct TermsUpdateSheet: View {
    let onAccept: () -> Void
    @State private var acceptsTerms = false
    @State private var acceptsSensitiveData = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 36))
                .foregroundStyle(Palette.brandGradient)
                .accessibilityHidden(true)
            Text("We've updated our terms")
                .font(.glimpseTitle2)
            Text("Please take a look and confirm to keep using Glimpse.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
            ConsentToggles(acceptsTerms: $acceptsTerms, acceptsSensitiveData: $acceptsSensitiveData)
            Spacer(minLength: 0)
            Button("Continue", action: onAccept)
                .buttonStyle(.glimpse)
                .disabled(!acceptsTerms || !acceptsSensitiveData)
        }
        .padding(24)
        .background(Palette.midnight)
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
}
