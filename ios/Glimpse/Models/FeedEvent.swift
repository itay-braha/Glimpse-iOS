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
    }

    let target: UUID
    let kind: Kind
    var dwellMs: Int?

    enum CodingKeys: String, CodingKey {
        case target
        case kind
        case dwellMs = "dwell_ms"
    }
}
