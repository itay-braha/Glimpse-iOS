import Foundation

/// How one of your clips did over the last 30 days (Glimpse Gold). Totals only;
/// the rates appear once 5+ different people have seen the clip.
struct ClipInsight: Codable, Hashable, Identifiable, Sendable {
    let videoID: UUID
    let viewers: Int
    let enoughData: Bool
    /// Share of showings watched to the end of the clip time (0–1).
    let watchedThrough: Double?
    /// Share of showings where the viewer tapped on to the next clip (0–1).
    let skipped: Double?
    let moreTaps: Int?
    let likes: Int?

    var id: UUID { videoID }

    enum CodingKeys: String, CodingKey {
        case videoID = "video_id"
        case viewers
        case enoughData = "enough_data"
        case watchedThrough = "watched_through"
        case skipped
        case moreTaps = "more_taps"
        case likes
    }
}
