import Foundation

/// Feedback questions (why a connection ended) are asked at most once a week, so
/// nobody gets survey fatigue. The private after-date check-in is paced on the server.
enum SurveyPacing {
    private static let key = "survey.lastAskedAt"
    static let gap: TimeInterval = 7 * 86_400

    static func mayAsk(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        let last = defaults.double(forKey: key)
        return last == 0 || now.timeIntervalSince1970 - last >= gap
    }

    static func recordAsked(now: Date = .now, defaults: UserDefaults = .standard) {
        defaults.set(now.timeIntervalSince1970, forKey: key)
    }
}
