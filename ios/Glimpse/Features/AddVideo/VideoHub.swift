import SwiftUI

/// The three ways to add a moment.
enum AddVideoRoute: String, Hashable, Identifiable {
    case upload
    case embed
    case inspiration

    var id: String { rawValue }
}

struct GlimpseOfYouHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Let others get a Glimpse of \(Text("YOU").foregroundStyle(Palette.brandGradient))")
                .font(.glimpseTitle)
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Your profile comes to life in video. Pick how you want to show up. Every moment shows when it was added, so people see the real, current you.")
                .font(.glimpseBody)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct VideoHubOptions: View {
    /// Links only once there's a clip of your own to anchor the profile.
    var canLink = true
    let onSelect: (AddVideoRoute) -> Void

    var body: some View {
        VStack(spacing: 12) {
            VideoSourceCard(
                symbol: "photo.on.rectangle.angled",
                tint: Palette.mint,
                title: "Quick upload",
                detail: "A clip from your camera roll. Up to 15 seconds, private to Glimpse."
            ) { onSelect(.upload) }
                .accessibilityIdentifier("hub.upload")

            VideoSourceCard(
                title: "Link from Instagram or TikTok",
                detail: canLink
                    ? String(localized: "A public Reel or TikTok from the last year. We'll walk you through it.")
                    : String(localized: "Unlocks after your first clip. Links sit on top of a clip of your own."),
                action: { onSelect(.embed) }
            ) {
                ZStack {
                    PlatformGlyph(platform: .instagram, size: 34)
                        .offset(x: -7, y: -7)
                    PlatformGlyph(platform: .tiktok, size: 34)
                        .offset(x: 8, y: 8)
                }
            }
                .disabled(!canLink)
                .accessibilityIdentifier("hub.embed")

            VideoSourceCard(
                symbol: "sparkles",
                tint: Palette.violet,
                title: "Get a Glimpse idea",
                detail: "Three quick prompts and your camera. No overthinking."
            ) { onSelect(.inspiration) }
                .accessibilityIdentifier("hub.inspiration")
        }
    }
}

struct AddVideoDestination: View {
    let route: AddVideoRoute
    let onAdded: (ProfileVideo) -> Void
    /// Moves to another way of adding (a Story link goes to Quick upload).
    var onSwitch: (AddVideoRoute) -> Void = { _ in }

    var body: some View {
        switch route {
        case .upload: UploadVideoView(onAdded: onAdded)
        case .embed: EmbedLinkView(onAdded: onAdded) { onSwitch(.upload) }
        case .inspiration: InspirationView(onAdded: onAdded)
        }
    }
}

/// Profile "Add" flow: the hub, then one of the three ways, in one sheet.
struct AddVideoSheet: View {
    var canLink = true
    var startAt: AddVideoRoute?
    let onAdded: (ProfileVideo) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var path: [AddVideoRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    GlimpseOfYouHeader()
                    VideoHubOptions(canLink: canLink) { path.append($0) }
                }
                .padding(20)
            }
            .background(Palette.midnight)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(for: AddVideoRoute.self) { route in
                AddVideoDestination(route: route) { video in
                    onAdded(video)
                    dismiss()
                } onSwitch: { next in
                    path = [next]
                }
            }
        }
        .onAppear {
            if let startAt, path.isEmpty { path = [startAt] }
        }
    }
}
