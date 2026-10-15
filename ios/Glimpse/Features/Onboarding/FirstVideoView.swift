import SwiftUI

/// Glimpse profiles are video-only, so onboarding ends with the first moment.
struct FirstVideoView: View {
    @Environment(AppModel.self) private var app
    @State private var showRecorder = false
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        OnboardingScaffold(
            title: "Add your first moment",
            subtitle: "No studio shots. Pull a recent Reel or record 15 seconds of you being you. Every clip shows when it was added, so profiles stay current."
        ) {
            VideoSourceCard(
                symbol: "camera.aperture",
                tint: Palette.pink,
                title: "Import from Instagram",
                detail: "Your recent Reels, from the last 90 days."
            ) {
                Task { await importFromInstagram() }
            }
            .disabled(isImporting)

            VideoSourceCard(
                symbol: "music.note",
                tint: Color(hex: 0x7AF0FF),
                title: "Import from TikTok",
                detail: "Coming soon"
            ) {}
            .disabled(true)

            VideoSourceCard(
                symbol: "record.circle",
                tint: Palette.mint,
                title: "Record a clip",
                detail: "Up to 15 seconds, right here."
            ) {
                showRecorder = true
            }

            if isImporting {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Importing your Reels…").foregroundStyle(Palette.textSecondary)
                }
            }

            if let errorMessage {
                ErrorText(errorMessage)
            }
        } footer: {
            Button("Sign out") {
                Task { await app.signOut() }
            }
            .font(.subheadline)
            .foregroundStyle(Palette.textTertiary)
            .frame(maxWidth: .infinity)
        }
        .fullScreenCover(isPresented: $showRecorder) {
            RecorderView { _ in
                Task { await app.refreshProfile() }
            }
        }
    }

    private func importFromInstagram() async {
        isImporting = true
        defer { isImporting = false }
        do {
            let imported = try await InstagramImporter.run(backend: app.backend, config: app.config)
            if imported.isEmpty {
                errorMessage = "No Reels from the last 90 days were found. Try recording a clip instead."
            }
            await app.refreshProfile()
        } catch InstagramImporter.Failure.cancelled {
            return
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }
}

struct VideoSourceCard: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.glimpseHeadline).foregroundStyle(Palette.textPrimary)
                    Text(detail).font(.subheadline).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Palette.surface, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.stroke))
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
    }
}
