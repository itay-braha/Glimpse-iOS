import SwiftUI

/// "Link a public Reel or TikTok": nothing is copied; the post plays through the
/// platform's official player. Because viewers can tap through to the owner's
/// social profile, adding one requires an explicit acknowledgement.
struct EmbedLinkView: View {
    let onAdded: (ProfileVideo) -> Void

    @Environment(AppModel.self) private var app
    @State private var text = ""
    @State private var link: EmbedLink?
    @State private var isExpanding = false
    @State private var consent = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Link a public video")
                    .font(.glimpseTitle2)
                Text("Paste a link to one of your public Instagram posts or Reels, or a TikTok video. It plays on your profile through the platform's official player. Nothing is copied to Glimpse.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                field
                status

                if let link {
                    EmbedStage(link: link)
                        .aspectRatio(9 / 16, contentMode: .fit)
                        .frame(maxWidth: 260)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("embed.preview")
                    disclosure(for: link)
                }

                if let errorMessage {
                    ErrorText(errorMessage)
                }

                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().tint(Palette.onMint)
                    } else {
                        Text("Add to my profile")
                    }
                }
                .buttonStyle(.glimpse)
                .disabled(link == nil || !consent || isSaving)
                .accessibilityIdentifier("embed.add")
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.midnight)
        .navigationTitle("Link a video")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: text) { await resolve() }
        .onChange(of: link) { consent = false }
    }

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "link").foregroundStyle(Palette.textTertiary)
            TextField("instagram.com/reel/… or tiktok.com/@you/video/…", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.done)
                .accessibilityIdentifier("embed.field")
            if !text.isEmpty {
                Button("Clear", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Palette.textTertiary)
            }
            PasteButton(payloadType: String.self) { strings in
                if let first = strings.first { text = first }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.capsule)
            .tint(Palette.violet)
        }
        .padding(14)
        .background(Palette.surface, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(link == nil ? Palette.stroke : Palette.mint.opacity(0.6)))
    }

    @ViewBuilder
    private var status: some View {
        if let link {
            Label("\(link.platform.name) video found", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.mint)
                .accessibilityIdentifier("embed.found")
        } else if isExpanding {
            Label("Opening the share link…", systemImage: "hourglass")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        } else if !text.trimmingCharacters(in: .whitespaces).isEmpty {
            Label("Use a link to a single public post on Instagram or TikTok.", systemImage: "info.circle")
                .font(.subheadline)
                .foregroundStyle(Palette.amber)
        }
    }

    private func disclosure(for link: EmbedLink) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This links to your \(link.platform.name)")
                        .font(.glimpseHeadline)
                    Text("Anyone who taps this video can open it in \(link.platform.name), where your username, profile and other posts are visible. Glimpse never shows your handle anywhere else.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.amber)
            }
            Toggle("I understand, add it anyway", isOn: $consent)
                .font(.subheadline.weight(.semibold))
                .tint(Palette.mint)
                .accessibilityIdentifier("embed.consent")
        }
        .padding(14)
        .background(Palette.amber.opacity(0.08), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.amber.opacity(0.35)))
    }

    private func resolve() async {
        errorMessage = nil
        if let parsed = EmbedLink.parse(text) {
            link = parsed
            return
        }
        link = nil
        guard EmbedLink.needsExpansion(text) else { return }
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        isExpanding = true
        let expanded = await EmbedLink.expand(text)
        isExpanding = false
        guard !Task.isCancelled else { return }
        link = EmbedLink.parse(expanded)
    }

    private func save() async {
        guard let link else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let video = try await app.backend.addEmbed(link, promptKey: nil)
            onAdded(video)
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }
}
