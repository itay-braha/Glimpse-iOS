import SwiftUI
import WebKit

/// Plays a public Instagram / TikTok post through the platform's official embed
/// player, in a sandboxed web view:
///   * non-persistent data store: no cookies or logins shared with Safari or the apps;
///   * no script bridges into Glimpse;
///   * any tap that leaves the player (profile, "View on Instagram", …) opens
///     outside Glimpse, in the platform's app when installed.
/// Demo builds show a stand-in instead of calling the platforms.
struct EmbedPlayerView: View {
    let link: EmbedLink
    var isActive = true

    @Environment(AppModel.self) private var app
    @State private var hasStarted = false

    var body: some View {
        ZStack {
            Color.black
            if app.isDemo {
                DemoEmbedStandIn(link: link)
            } else if hasStarted {
                EmbedWebView(link: link, isActive: isActive)
            } else {
                ProgressView().tint(.white)
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            // Load lazily: off-screen cards in the feed don't pull the platform's player.
            if active { hasStarted = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(link.platform.name) video")
    }
}

/// "Instagram ↗": tells viewers that tapping leaves Glimpse, and does it.
struct PlatformBadge: View {
    let link: EmbedLink
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
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

    var body: some View {
        EmbedPlayerView(link: link, isActive: isActive)
            .clipShape(.rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.14)))
            .overlay(alignment: .topTrailing) {
                PlatformBadge(link: link).padding(10)
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

private struct EmbedWebView: UIViewRepresentable {
    let link: EmbedLink
    let isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator(link: link) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        view.scrollView.bounces = false
        view.allowsLinkPreview = false
        view.load(URLRequest(url: link.playerURL))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        if !isActive {
            view.evaluateJavaScript("document.querySelectorAll('video').forEach(function (v) { v.pause(); })")
        }
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.evaluateJavaScript("document.querySelectorAll('video').forEach(function (v) { v.pause(); })")
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let link: EmbedLink

        init(link: EmbedLink) {
            self.link = link
        }

        /// Hosts the player itself may use. Anything else, or any tap on a link,
        /// leaves Glimpse.
        private var playerHosts: [String] {
            switch link.platform {
            case .instagram: ["instagram.com", "cdninstagram.com", "facebook.com", "fbcdn.net"]
            case .tiktok: ["tiktok.com", "tiktokcdn.com", "tiktokv.com", "ttwstatic.com"]
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .cancel }
            let host = url.host()?.lowercased() ?? ""
            let isPlayerHost = playerHosts.contains { host == $0 || host.hasSuffix("." + $0) }
            let isSubframe = action.targetFrame?.isMainFrame == false

            if action.navigationType == .linkActivated || (!isPlayerHost && !isSubframe && url.scheme != "about") {
                openOutside(url)
                return .cancel
            }
            return .allow
        }

        /// `target=_blank` links: never open a second web view.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for action: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = action.request.url { openOutside(url) }
            return nil
        }

        private func openOutside(_ url: URL) {
            guard url.scheme == "https" else { return }
            UIApplication.shared.open(url)
        }
    }
}
