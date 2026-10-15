import Observation
import UIKit
import WebKit

/// Loads one linked post in the platform's official embed player and decides,
/// before anyone has to look at it, whether it actually plays.
///
/// Sandbox: non-persistent data store (no cookies or logins shared with Safari or
/// the apps), no script bridges into Glimpse, and any tap that would leave the
/// player opens outside Glimpse (the platform's app when installed).
@MainActor
@Observable
final class EmbedLoader: NSObject, WKNavigationDelegate, WKUIDelegate {
    enum State: Equatable {
        case loading
        case ready
        /// Deleted, private or expired: the platform shows nothing to play.
        case dead
    }

    private(set) var state: State = .loading
    let link: EmbedLink
    let webView: WKWebView
    /// Called once when the post turns out to be dead.
    @ObservationIgnored var onDead: (@MainActor () -> Void)?

    init(link: EmbedLink) {
        self.link = link
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 693), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.allowsLinkPreview = false
        webView.load(URLRequest(url: link.playerURL))
    }

    func setPlaying(_ playing: Bool) {
        guard !playing else { return }
        webView.evaluateJavaScript("document.querySelectorAll('video').forEach(function (v) { v.pause(); })")
    }

    private func settle(_ verdict: State) {
        guard state == .loading else { return }
        state = verdict
        if verdict == .dead { onDead?() }
    }

    // MARK: Verdict

    /// The player page itself answered "gone". Network errors on this phone are never a verdict.
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if response.isForMainFrame, let http = response.response as? HTTPURLResponse, [404, 410].contains(http.statusCode) {
            settle(.dead)
        }
        return .allow
    }

    /// Loaded: give the player a moment to draw, then look for the platform's "unavailable" card.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self, self.state == .loading else { return }
            let text = (try? await self.webView.evaluateJavaScript("document.body ? document.body.innerText : ''")) as? String ?? ""
            self.settle(EmbedHealth.looksUnavailable(text) ? .dead : .ready)
        }
    }

    // MARK: Sandbox

    /// Hosts the player itself may use. Anything else, or any tap on a link, leaves Glimpse.
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

/// Keeps players for the next few linked posts loading in the background, so a
/// post is checked (and usually ready to play) before the viewer reaches it.
/// Dead posts are dropped from the feed before anyone sees them.
@MainActor
final class EmbedPrewarmer {
    static let shared = EmbedPrewarmer()

    /// Live players kept around (the ones on screen plus the look-ahead).
    private let capacity = 6
    private var loaders: [UUID: EmbedLoader] = [:]
    private var recency: [UUID] = []

    private init() {}

    /// Starts checking a viewer-facing linked post ahead of time.
    func warm(_ video: ProfileVideo, using backend: any GlimpseBackend) {
        guard let link = video.embedLink, !EmbedHealth.shared.deadForMe.contains(video.id) else { return }
        _ = loader(for: link, videoID: video.id, using: backend)
    }

    /// The pooled player for someone else's post, or a private one for the owner's own preview.
    func loader(for link: EmbedLink, videoID: UUID?, using backend: any GlimpseBackend) -> EmbedLoader {
        guard let videoID else { return EmbedLoader(link: link) }
        if let existing = loaders[videoID] {
            touch(videoID)
            return existing
        }
        let loader = EmbedLoader(link: link)
        loader.onDead = { EmbedHealth.shared.markDead(videoID, using: backend) }
        loaders[videoID] = loader
        touch(videoID)
        // Oldest players leave the pool; a card still showing one keeps it alive.
        while recency.count > capacity {
            loaders.removeValue(forKey: recency.removeFirst())
        }
        return loader
    }

    private func touch(_ id: UUID) {
        recency.removeAll { $0 == id }
        recency.append(id)
    }
}

/// Linked posts this viewer's phone found dead. They're dropped from every card
/// for the rest of the session and reported once, silently; enough viewers hide
/// the link for everyone.
@MainActor
@Observable
final class EmbedHealth {
    static let shared = EmbedHealth()

    private(set) var deadForMe: Set<UUID> = []

    private init() {}

    func markDead(_ videoID: UUID, using backend: any GlimpseBackend) {
        guard deadForMe.insert(videoID).inserted else { return }
        Task { await backend.reportEmbedUnplayable(videoID) }
    }

    /// Words the platforms' players show instead of a video.
    nonisolated static func looksUnavailable(_ pageText: String) -> Bool {
        let text = pageText.lowercased()
        return ["unavailable", "no longer available", "isn't available", "not available", "has been removed"]
            .contains { text.contains($0) }
    }
}
