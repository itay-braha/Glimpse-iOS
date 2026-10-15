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

    /// When the post was published, read from its id (nil if it can't be read).
    /// TikTok: the upper 32 bits of the video id are Unix seconds. Instagram: the
    /// 11-character shortcode is the media id in base64url, whose upper bits are
    /// milliseconds since Instagram's epoch. Mirrors `private.post_time_from_id`.
    var postDate: Date? {
        let date: Date
        switch platform {
        case .tiktok:
            guard let id = UInt64(postID) else { return nil }
            date = Date(timeIntervalSince1970: TimeInterval(id >> 32))
        case .instagram:
            let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
            guard postID.count == 11 else { return nil }
            var id: UInt64 = 0
            for character in postID {
                guard let digit = alphabet.firstIndex(of: character) else { return nil }
                let (shifted, overflow) = id.multipliedReportingOverflow(by: 64)
                guard !overflow else { return nil }
                id = shifted + UInt64(digit)
            }
            date = Date(timeIntervalSince1970: (Double(id >> 23) + 1_314_220_021_721) / 1000)
        }
        let earliest = Date(timeIntervalSince1970: 1_285_891_200) // Oct 2010
        guard date >= earliest, date <= Date.now.addingTimeInterval(86_400) else { return nil }
        return date
    }

    /// Instagram Stories and Highlights: Instagram can't embed them and Stories
    /// expire after 24 hours, so they're uploaded instead (Glimpse keeps a copy).
    static func isStory(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let regex = /^(https?:\/\/)?(www\.|m\.)?instagram\.com\/stories\//
        return text.firstMatch(of: regex) != nil
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
