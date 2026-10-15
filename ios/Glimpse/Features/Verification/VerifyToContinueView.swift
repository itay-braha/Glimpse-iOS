import SwiftUI

/// Shown when several members reported an account's videos as AI-generated:
/// the account is on hold until a live selfie check is approved.
struct VerifyToContinueView: View {
    @Environment(AppModel.self) private var app
    @State private var showVerification = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            VerifiedBadge(size: 64)
            Text("Verify it's you to continue")
                .font(.glimpseTitle2)
                .multilineTextAlignment(.center)
            Text("Some members thought your videos might be AI-generated. Glimpse is for real people, so we need a quick live selfie. Once it's approved, your profile is back.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Button("Start selfie check") { showVerification = true }
                .buttonStyle(.glimpse)
            Button("I've already sent it, check again") {
                Task { await app.retryLaunch() }
            }
            .buttonStyle(.glimpseSecondary)
            Button("Sign out") {
                Task { await app.signOut() }
            }
            .font(.subheadline)
            .foregroundStyle(Palette.textTertiary)
        }
        .padding(28)
        .sheet(isPresented: $showVerification) {
            VerificationView()
        }
    }
}
