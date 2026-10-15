import Foundation

/// Verified recency tags ("Added 3 days ago") and the 90-day rotation rule.
enum Recency {
    static let rotationThresholdDays = 90

    static func days(since date: Date, now: Date = .now) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0)
    }

    static func isStale(_ importedAt: Date, now: Date = .now) -> Bool {
        days(since: importedAt, now: now) >= rotationThresholdDays
    }

    static func label(_ importedAt: Date, now: Date = .now) -> String {
        let days = days(since: importedAt, now: now)
        switch days {
        case 0: return "Added today"
        case 1: return "Added yesterday"
        case 2..<14: return "Added \(days) days ago"
        case 14..<60: return "Added \(days / 7) weeks ago"
        default: return "Added \(days / 30) months ago"
        }
    }

    static func shortLabel(_ importedAt: Date, now: Date = .now) -> String {
        let days = days(since: importedAt, now: now)
        switch days {
        case 0: return "Today"
        case 1..<14: return "\(days)d"
        case 14..<60: return "\(days / 7)w"
        default: return "\(days / 30)mo"
        }
    }
}
