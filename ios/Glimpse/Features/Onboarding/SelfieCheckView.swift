import SwiftUI

/// The last step of signing up: a 5-second gesture selfie so everyone here is a real person.
/// A person on the team compares it with the profile clips; until it's approved the member
/// isn't shown to anyone. Asked for everyone, so nobody is singled out.
struct SelfieCheckView: View {
    @Environment(AppModel.self) private var app

    @State private var challenge: VerificationChallenge?
    @State private var showRecorder = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var status: String { app.profile?.verificationStatus ?? "none" }
    private var isWaiting: Bool { status == "pending" }

    var body: some View {
        Group {
            if isWaiting {
                waiting
            } else {
                ask
            }
        }
        .fullScreenCover(isPresented: $showRecorder) {
            if let challenge {
                RecorderView(purpose: .verification(challenge)) { _ in
                    app.track("selfie_submitted")
                    Task { await app.refreshSelfieStatus() }
                }
            }
        }
        .task {
            // Picks up an approval that came while the app was closed, then keeps checking.
            await app.refreshSelfieStatus()
        }
        .task(id: isWaiting) {
            while isWaiting, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                await app.refreshSelfieStatus()
            }
        }
    }

    // MARK: Ask

    private var ask: some View {
        OnboardingScaffold(
            title: "One quick selfie",
            subtitle: "So everyone here is real. It takes about 5 seconds."
        ) {
            if status == "rejected" {
                Label("That one didn't work. Please try again, facing the camera in good light.", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.amber)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.amber.opacity(0.12), in: .rect(cornerRadius: 14))
            }
            VStack(alignment: .leading, spacing: 12) {
                SelfieStep(number: 1, text: "We give you a random pose.")
                SelfieStep(number: 2, text: "You record a 5-second selfie doing it.")
                SelfieStep(number: 3, text: "A person on our team compares it with your clips, usually within a day.")
            }
            if let challenge {
                Label(challenge.gesture, systemImage: "hand.raised.fill")
                    .font(.glimpseHeadline)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.mint.opacity(0.12), in: .rect(cornerRadius: 16))
                    .accessibilityIdentifier("selfie.pose")
            }
            Label("Only our review team sees it, and we delete it 30 days after the review.", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(Palette.textTertiary)
            if let errorMessage {
                ErrorText(errorMessage)
            }
        } footer: {
            VStack(spacing: 10) {
                Button {
                    Task { await startOrRecord() }
                } label: {
                    if isLoading {
                        ProgressView().tint(Palette.onMint)
                    } else {
                        Text(challenge == nil ? String(localized: "Get my pose") : String(localized: "Record selfie"))
                    }
                }
                .buttonStyle(.glimpse)
                .disabled(isLoading)
                .accessibilityIdentifier(challenge == nil ? "selfie.getPose" : "selfie.record")
                signOutButton
            }
        }
    }

    private func startOrRecord() async {
        if challenge != nil {
            showRecorder = true
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            challenge = try await app.backend.startVerification()
            errorMessage = nil
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }

    // MARK: Waiting

    private var waiting: some View {
        OnboardingScaffold(
            title: "We're checking your selfie",
            subtitle: "A person on our team is comparing it with your clips, usually within a day. We'll notify you the moment you're in."
        ) {
            HStack(spacing: 14) {
                ProgressView().tint(Palette.mint)
                Text("Nothing else to do. You can close the app.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: .rect(cornerRadius: 16))
            .accessibilityIdentifier("selfie.waiting")
        } footer: {
            VStack(spacing: 10) {
                Button("Check again") {
                    Task { await app.refreshSelfieStatus() }
                }
                .buttonStyle(.glimpseSecondary)
                .accessibilityIdentifier("selfie.checkAgain")
                signOutButton
            }
        }
    }

    private var signOutButton: some View {
        Button("Sign out") {
            Task { await app.signOut() }
        }
        .font(.subheadline)
        .foregroundStyle(Palette.textTertiary)
    }
}

private struct SelfieStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.glimpseCaption)
                .foregroundStyle(Palette.onMint)
                .frame(width: 24, height: 24)
                .background(Palette.mint, in: .circle)
            Text(LocalizedStringKey(text))
                .foregroundStyle(Palette.textSecondary)
        }
    }
}
