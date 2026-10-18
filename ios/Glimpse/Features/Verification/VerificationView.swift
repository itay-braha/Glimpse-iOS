import SwiftUI

/// Selfie-video verification: the server picks a random gesture, the user
/// records a 5-second selfie doing it, and a moderator compares it with their
/// profile moments. Approved profiles get the verified badge.
struct VerificationView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var challenge: VerificationChallenge?
    @State private var showRecorder = false
    @State private var submitted = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VerifiedBadge(size: 56)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                if submitted {
                    Text("Thanks! We're reviewing it.")
                        .font(.glimpseTitle2)
                    Text("You'll get a notification when your badge is ready. This usually takes less than a day.")
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    Text("Show you're the person in your moments")
                        .font(.glimpseTitle2)
                    VStack(alignment: .leading, spacing: 12) {
                        Step(number: 1, text: "We give you a random pose.")
                        Step(number: 2, text: "You record a 5-second selfie doing it.")
                        Step(number: 3, text: "A person on our team compares it with your profile. The selfie is never shown to anyone else.")
                    }
                    if let challenge {
                        Label(challenge.gesture, systemImage: "hand.raised.fill")
                            .font(.glimpseHeadline)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.mint.opacity(0.12), in: .rect(cornerRadius: 16))
                    }
                }

                if let errorMessage {
                    ErrorText(errorMessage)
                }

                Spacer()

                if submitted {
                    Button("Done") { dismiss() }
                        .buttonStyle(.glimpse)
                } else {
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
                }
            }
            .padding(24)
            .background(Palette.midnight)
            .navigationTitle("Get verified")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .fullScreenCover(isPresented: $showRecorder) {
            if let challenge {
                RecorderView(purpose: .verification(challenge)) { _ in
                    submitted = true
                    app.track("verification_submitted")
                    Task { await app.refreshProfile() }
                }
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
}

private struct Step: View {
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
