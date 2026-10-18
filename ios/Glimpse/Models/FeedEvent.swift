import Foundation

/// An implicit signal from the feed (watch time, rewatch, unmute…) that teaches
/// discovery what someone actually responds to. Sent in batches.
struct FeedEvent: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case view
        case rewatch
        case unmute
        case linkOpen = "link_open"
        case clipNext = "clip_next"
        /// Per clip (with `video`): shown, watched to the end of its time, "+more", liked while showing.
        case clipShown = "clip_shown"
        case clipComplete = "clip_complete"
        case clipMore = "clip_more"
        case clipLiked = "clip_liked"
    }

    let target: UUID
    let kind: Kind
    var dwellMs: Int?
    /// The clip the signal is about, for clip insights.
    var video: UUID?

    enum CodingKeys: String, CodingKey {
        case target
        case kind
        case dwellMs = "dwell_ms"
        case video
    }
}
