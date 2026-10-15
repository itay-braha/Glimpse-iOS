import Foundation

/// Converts between `Date` and the `yyyy-MM-dd` strings Postgres uses for `date` columns.
enum BirthdateFormat {
    private static let style = Date.ISO8601FormatStyle(timeZone: .gmt).year().month().day()

    static func string(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 2000, components.month ?? 1, components.day ?? 1)
    }

    static func date(from string: String) -> Date? {
        try? Date(string, strategy: style)
    }

    static func age(from date: Date, now: Date = .now) -> Int {
        Calendar.current.dateComponents([.year], from: date, to: now).year ?? 0
    }
}
