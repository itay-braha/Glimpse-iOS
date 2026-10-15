import SwiftUI
import WebKit

/// Plays a public Instagram / TikTok post through the platform's official embed
/// player (see `EmbedLoader` for the sandbox). The feed warms players for the
/// next few profiles, so this usually finds one already checked and ready. A
/// player stays out of sight until the post has loaded; if the post is dead,
/// viewers never see the platform's "unavailable" card (the card drops the clip),
/// while owners do, so they know. Demo builds show a stand-in instead.
struct EmbedPlayerView: View {
    let link: EmbedLink
    var isActive = true
    /// Set for other people's videos (pooled, checked, reported if dead).
    var videoID: UUID?

    @Environment(AppModel.self) private var app
    @State private var loader: EmbedLoader?

    private var isOwnerPreview: Bool { videoID == nil }

    var body: some View {
        ZStack {
            Color.black
            if app.isDemo {
                DemoEmbedStandIn(link: link)
            } else if let loader {
                EmbedWebHost(webView: loader.webView)
                    .opacity(loader.state == .ready || (isOwnerPreview && loader.state == .dead) ? 1 : 0)
                if loader.state == .loading {
                    ProgressView().tint(.white)
                }
            } else {
                ProgressView().tint(.white)
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            // Off-screen cards don't create players; the feed's look-ahead warms them instead.
            if active, loader == nil, !app.isDemo {
                loader = EmbedPrewarmer.shared.loader(for: link, videoID: videoID, using: app.backend)
            }
            loader?.setPlaying(active)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(link.platform.name) video")
    }
}

/// Hosts a (possibly pre-warmed) web view; detaching it on teardown lets the
/// same player move to whichever card shows it next.
private struct EmbedWebHost: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        attach(to: container)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        if webView.superview !== container { attach(to: container) }
    }

    static func dismantleUIView(_ container: UIView, coordinator: ()) {
        container.subviews.forEach { $0.removeFromSuperview() }
    }

    private func attach(to container: UIView) {
        webView.removeFromSuperview()
        webView.frame = container.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(webView)
    }
}

/// "Instagram ↗": tells viewers that tapping leaves Glimpse, and does it.
struct PlatformBadge: View {
    let link: EmbedLink
    var onOpen: (() -> Void)?
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            onOpen?()
            openURL(link.canonicalURL)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: link.platform == .instagram ? "camera.aperture" : "music.note")
                    .font(.caption.weight(.bold))
                Text(link.platform.name)
                    .font(.caption.weight(.heavy))
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(platformTint, in: .capsule)
            .overlay(Capsule().strokeBorder(.white.opacity(0.25)))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open in \(link.platform.name)")
        .accessibilityHint("Leaves Glimpse. Their \(link.platform.name) profile is visible there.")
        .accessibilityIdentifier("platformBadge")
    }

    private var platformTint: some ShapeStyle {
        switch link.platform {
        case .instagram:
            LinearGradient(colors: [Color(hex: 0xF58529), Color(hex: 0xDD2A7B), Color(hex: 0x8134AF)], startPoint: .leading, endPoint: .trailing)
        case .tiktok:
            LinearGradient(colors: [Color(hex: 0x111111), Color(hex: 0x2A2A2A)], startPoint: .leading, endPoint: .trailing)
        }
    }
}

/// The embed, framed for full-screen cards: rounded stage with the platform badge.
struct EmbedStage: View {
    let link: EmbedLink
    var isActive = true
    var videoID: UUID?
    var onOpenLink: (() -> Void)?

    var body: some View {
        EmbedPlayerView(link: link, isActive: isActive, videoID: videoID)
            .clipShape(.rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.14)))
            .overlay(alignment: .topTrailing) {
                PlatformBadge(link: link, onOpen: onOpenLink).padding(10)
            }
    }
}

private struct DemoEmbedStandIn: View {
    let link: EmbedLink

    var body: some View {
        ZStack {
            Palette.seededGradient(link.postID)
            VStack(spacing: 14) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.white.opacity(0.9))
                Text("\(link.platform.name)'s official player")
                    .font(.glimpseHeadline)
                    .foregroundStyle(.white)
                Text("Plays the public post here. Demo builds don't contact \(link.platform.name).")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 28)
            }
        }
    }
}
