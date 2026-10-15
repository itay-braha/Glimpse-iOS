import Foundation

/// A public Instagram post/Reel or TikTok video someone links to from their
/// profile. Mirrors `private.parse_embed_url` on the server (which has the
/// final say): share-sheet noise is stripped so one post has one canonical URL.
struct EmbedLink: Equatable, Sendable {
    enum Platform: String, Sendable {
        case instagram
        case tiktok

        var name: String {
            switch self {
            case .instagram: "Instagram"
            case .tiktok: "TikTok"
            }
        }

        var source: VideoSource {
            switch self {
            case .instagram: .instagram
            case .tiktok: .tiktok
            }
        }
    }

    let platform: Platform
    let postID: String
    /// Public permalink; opens the post in the platform's app via universal links.
    let canonicalURL: URL
    /// The platform's official embed player for this post.
    let playerURL: URL

    /// Parses a pasted link. Adds a missing `https://`; returns nil for anything
    /// that isn't a single public post on a supported platform.
    static func parse(_ raw: String) -> EmbedLink? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 500 else { return nil }
        if !text.lowercased().hasPrefix("http") {
            text = "https://" + text
        }
        // Built per call: `Regex` values aren't Sendable, so they can't be shared statics.
        let instagram = /^https?:\/\/(?:www\.|m\.)?instagram\.com\/(?:[A-Za-z0-9._]{1,30}\/)?(reels?|p|tv)\/([A-Za-z0-9_-]{5,64})\/?(?:[?#].*)?$/
            .ignoresCase()
        let tiktok = /^https?:\/\/(?:www\.|m\.)?tiktok\.com\/@([A-Za-z0-9._]{1,32})\/video\/([0-9]{6,32})\/?(?:[?#].*)?$/
            .ignoresCase()

        if let match = text.wholeMatch(of: instagram) {
            let kind = switch match.1.lowercased() {
            case "p": "p"
            case "tv": "tv"
            default: "reel"
            }
            let id = String(match.2)
            guard let canonical = URL(string: "https://www.instagram.com/\(kind)/\(id)/"),
                  let player = URL(string: "https://www.instagram.com/\(kind)/\(id)/embed/")
            else { return nil }
            return EmbedLink(platform: .instagram, postID: id, canonicalURL: canonical, playerURL: player)
        }

        if let match = text.wholeMatch(of: tiktok) {
            let user = match.1.lowercased()
            let id = String(match.2)
            guard let canonical = URL(string: "https://www.tiktok.com/@\(user)/video/\(id)"),
                  let player = URL(string: "https://www.tiktok.com/player/v1/\(id)?autoplay=1&loop=1&muted=1&rel=0&description=0&music_info=0")
            else { return nil }
            return EmbedLink(platform: .tiktok, postID: id, canonicalURL: canonical, playerURL: player)
        }
        return nil
    }

    /// Share links like vm.tiktok.com/ZM… redirect to the full URL; nothing else needs expanding.
    static func needsExpansion(_ raw: String) -> Bool {
        let host = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))?.host()?.lowercased() ?? ""
        return host == "vm.tiktok.com" || host == "vt.tiktok.com"
            || (host.hasSuffix("tiktok.com") && raw.contains("/t/"))
    }

    /// Follows a short link's redirects (no cookies) and returns the final URL.
    static func expand(_ raw: String) async -> String {
        guard needsExpansion(raw), let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return raw
        }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "HEAD"
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        guard let (_, response) = try? await session.data(for: request), let final = response.url else {
            return raw
        }
        return final.absoluteString
    }
}
