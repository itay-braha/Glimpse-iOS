import SwiftUI

/// "Link a public Reel or TikTok", as a guided three-step flow:
///   1. pick the app (Instagram or TikTok),
///   2. follow the steps to copy the post's link (with a button that opens the app),
///   3. paste it here.
/// Nothing is copied; the post plays through the platform's official player.
/// Because viewers can tap through to the owner's social profile, adding one
/// needs an explicit acknowledgement. Stories expire, so they're sent to Quick
/// upload; posts older than 12 months are refused (the date comes from the link).
struct EmbedLinkView: View {
    let onAdded: (ProfileVideo) -> Void
    /// Switches to Quick upload (for Stories, which can't be linked).
    var onUseUpload: () -> Void = {}

    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL
    @State private var platform: EmbedLink.Platform?
    @State private var text = ""
    @State private var link: EmbedLink?
    @State private var isExpanding = false
    @State private var consent = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isTooOld: Bool {
        link?.postDate.map { Recency.isTooOldToAdd($0) } ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Link a public video")
                        .font(.glimpseTitle2)
                    Text("Already posted something great? It plays right on your profile. Nothing is copied to Glimpse.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                StepHeader(number: 1, title: "Where is it posted?")
                HStack(spacing: 12) {
                    PlatformChoice(platform: .instagram, detail: "Reel or post", isSelected: platform == .instagram) {
                        platform = .instagram
                    }
                    PlatformChoice(platform: .tiktok, detail: "Video", isSelected: platform == .tiktok) {
                        platform = .tiktok
                    }
                }

                if let platform {
                    StepHeader(number: 2, title: "Copy its link")
                    copySteps(for: platform)
                }

                StepHeader(number: platform == nil ? 2 : 3, title: "Paste it here")
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first { text = first }
                }
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .tint(Palette.mint)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("embed.paste")
                field

                if EmbedLink.isStory(text) {
                    storyNotice
                } else if isTooOld, let date = link?.postDate {
                    tooOldNotice(date)
                } else {
                    status
                }

                if let link, !isTooOld {
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
                .disabled(link == nil || isTooOld || !consent || isSaving)
                .accessibilityIdentifier("embed.add")
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.midnight)
        .navigationTitle("Link a video")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: text) { await resolve() }
        .onChange(of: link) { _, newLink in
            consent = false
            // A pasted link picks its app, so the steps match what was pasted.
            if let newLink { platform = newLink.platform }
        }
    }

    // MARK: Step 2: how to copy the link

    private func copySteps(for platform: EmbedLink.Platform) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            InstructionRow(index: "a", text: platform == .instagram
                ? "Open the Reel or post in Instagram."
                : "Open the video in TikTok.")
            InstructionRow(index: "b", text: platform == .instagram
                ? "Tap the paper plane (Share) under it."
                : "Tap the arrow (Share) on the right.")
            InstructionRow(index: "c", text: "Tap \"Copy link\", then come back here.")
            Button {
                openURL(platform == .instagram ? URL(string: "https://www.instagram.com/")! : URL(string: "https://www.tiktok.com/")!)
            } label: {
                HStack(spacing: 10) {
                    PlatformGlyph(platform: platform, size: 26)
                    Text("Open \(platform.name)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glimpseSecondary)
            .accessibilityIdentifier("embed.openApp")
            Text("Only public posts from the last 12 months. Stories can't be linked; upload them instead.")
                .font(.footnote)
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(14)
        .background(Palette.surface, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.stroke))
    }

    // MARK: Step 3: the link

    private var field: some View {
        HStack(spacing: 10) {
            Image(systemName: "link").foregroundStyle(Palette.textTertiary)
            TextField("or type the link", text: $text)
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
        }
        .padding(14)
        .background(Palette.surface, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(link == nil ? Palette.stroke : Palette.mint.opacity(0.6)))
    }

    @ViewBuilder
    private var status: some View {
        if let link {
            HStack(spacing: 8) {
                PlatformGlyph(platform: link.platform, size: 22)
                Text(foundText(for: link))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.mint)
                    .accessibilityIdentifier("embed.found")
            }
        } else if isExpanding {
            Label("Opening the share link…", systemImage: "hourglass")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        } else if !text.trimmingCharacters(in: .whitespaces).isEmpty {
            Label("That isn't a link to a single public Instagram post or TikTok video.", systemImage: "info.circle")
                .font(.subheadline)
                .foregroundStyle(Palette.amber)
        }
    }

    private func foundText(for link: EmbedLink) -> String {
        guard let posted = link.postDate else { return "\(link.platform.name) video found" }
        return "\(link.platform.name) video found · \(Recency.label(posted, verb: "posted").lowercased())"
    }

    private var storyNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stories can't be linked")
                        .font(.glimpseHeadline)
                    Text("Stories disappear after 24 hours, so your profile would go blank. Save it to your camera roll and upload it instead. Glimpse keeps a private copy.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "clock.badge.xmark").foregroundStyle(Palette.pink)
            }
            Button("Upload it instead", systemImage: "photo.on.rectangle", action: onUseUpload)
                .buttonStyle(.glimpseSecondary)
                .accessibilityIdentifier("embed.useUpload")
        }
        .padding(14)
        .background(Palette.pink.opacity(0.08), in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.pink.opacity(0.35)))
    }

    private func tooOldNotice(_ date: Date) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("That one's from \(date.formatted(.dateTime.month(.wide).year()))")
                    .font(.glimpseHeadline)
                Text("Glimpse shows the real, current you, so linked posts need to be from the last 12 months. Pick a newer one, or upload a recent clip.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: "calendar.badge.exclamationmark").foregroundStyle(Palette.amber)
        }
        .padding(14)
        .background(Palette.amber.opacity(0.08), in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("embed.tooOld")
    }

    private func disclosure(for link: EmbedLink) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This links to your \(link.platform.name)")
                        .font(.glimpseHeadline)
                    Text("Anyone who taps this video can open it in \(link.platform.name), where your username, profile and other posts are visible. Glimpse never shows your handle anywhere else. If the post is deleted, made private or expires, we hide it.")
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

    // MARK: Actions

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

private struct StepHeader: View {
    let number: Int
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Palette.onMint)
                .frame(width: 26, height: 26)
                .background(Palette.mint, in: .circle)
            Text(LocalizedStringKey(title))
                .font(.glimpseHeadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct InstructionRow: View {
    let index: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(index)
                .font(.caption.weight(.heavy))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 18)
            Text(LocalizedStringKey(text))
                .font(.subheadline)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PlatformChoice: View {
    let platform: EmbedLink.Platform
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                PlatformGlyph(platform: platform, size: 48)
                VStack(spacing: 2) {
                    Text(platform.name).font(.glimpseHeadline).foregroundStyle(Palette.textPrimary)
                    Text(LocalizedStringKey(detail)).font(.caption).foregroundStyle(Palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Palette.surface, in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? Palette.mint : Palette.stroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(platform.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("embed.platform.\(platform.rawValue)")
    }
}

/// The platform's mark, drawn in its brand colors (a recognisable stand-in; the
/// app ships no third-party logos).
struct PlatformGlyph: View {
    let platform: EmbedLink.Platform
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: platform == .instagram ? "camera" : "music.note")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(background, in: .rect(cornerRadius: size * 0.28))
            .shadow(color: platform == .tiktok ? Color(hex: 0xFE2C55).opacity(0.5) : Color(hex: 0xDD2A7B).opacity(0.4), radius: 4, x: platform == .tiktok ? 1.5 : 0, y: platform == .tiktok ? 1.5 : 1)
            .accessibilityHidden(true)
    }

    private var background: some ShapeStyle {
        switch platform {
        case .instagram:
            LinearGradient(
                colors: [Color(hex: 0xFEDA75), Color(hex: 0xFA7E1E), Color(hex: 0xD62976), Color(hex: 0x962FBF), Color(hex: 0x4F5BD5)],
                startPoint: .bottomLeading, endPoint: .topTrailing
            )
        case .tiktok:
            LinearGradient(colors: [Color(hex: 0x010101), Color(hex: 0x1F1F1F)], startPoint: .top, endPoint: .bottom)
        }
    }
}
