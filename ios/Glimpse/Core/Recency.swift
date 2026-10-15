import Foundation

/// Verified recency tags ("Filmed 3 months ago") and the 12-month freshness rule.
/// Clips must be filmed or posted within the last year to be added; after a year
/// the owner sees a quiet "Refresh" mark, and past 15 months others stop seeing
/// the clip (the server's `expire_old_clips`, never someone's last clip).
enum Recency {
    static let maxClipAgeDays = 365
    static let rotationThresholdDays = maxClipAgeDays

    static func days(since date: Date, now: Date = .now) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0)
    }

    static func isStale(_ capturedAt: Date, now: Date = .now) -> Bool {
        days(since: capturedAt, now: now) >= rotationThresholdDays
    }

    /// True when a clip filmed/posted at `date` is too old to add.
    static func isTooOldToAdd(_ date: Date, now: Date = .now) -> Bool {
        days(since: date, now: now) > maxClipAgeDays
    }

    static func label(_ date: Date, now: Date = .now, verb: String = "Added") -> String {
        let days = days(since: date, now: now)
        switch days {
        case 0: return "\(verb) today"
        case 1: return "\(verb) yesterday"
        case 2..<14: return "\(verb) \(days) days ago"
        case 14..<60: return "\(verb) \(days / 7) weeks ago"
        default: return "\(verb) \(days / 30) months ago"
        }
    }

    /// "Recorded today" / "Filmed 3 months ago" / "Posted 2 weeks ago".
    static func label(for video: ProfileVideo, now: Date = .now) -> String {
        label(video.capturedAt, now: now, verb: verb(for: video))
    }

    static func verb(for video: ProfileVideo) -> String {
        if video.isEmbed { return "Posted" }
        return video.source == .native ? "Recorded" : "Filmed"
    }

    static func shortLabel(_ date: Date, now: Date = .now) -> String {
        let days = days(since: date, now: now)
        switch days {
        case 0: return "Today"
        case 1..<14: return "\(days)d"
        case 14..<60: return "\(days / 7)w"
        default: return "\(days / 30)mo"
        }
    }
}
