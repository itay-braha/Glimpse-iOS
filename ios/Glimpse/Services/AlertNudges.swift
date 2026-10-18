import Foundation

/// Decides whether an in-context alert offer may be shown, so people who chose
/// less are asked rarely and politely, never nagged:
/// - nothing in the first 2 days after their first alerts choice;
/// - at most one offer every 10 days, across all topics;
/// - each topic at most twice ever, and 30 days apart after a "Not now";
/// - "Don't ask again" ends that topic for good.
struct AlertNudges {
    static let quietAfterFirstChoice: TimeInterval = 2 * 86_400
    static let minimumGap: TimeInterval = 10 * 86_400
    static let topicCooldown: TimeInterval = 30 * 86_400
    static let maxAsksPerTopic = 2

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Decisions

    func mayAsk(_ topic: AlertNudge.Topic, now: Date = .now) -> Bool {
        if let first = date("alertNudge.firstChoice"), now.timeIntervalSince(first) < Self.quietAfterFirstChoice {
            return false
        }
        if let last = date("alertNudge.lastAsked"), now.timeIntervalSince(last) < Self.minimumGap {
            return false
        }
        if defaults.bool(forKey: key(topic, "never")) { return false }
        if defaults.integer(forKey: key(topic, "count")) >= Self.maxAsksPerTopic { return false }
        if let declined = date(key(topic, "declined")), now.timeIntervalSince(declined) < Self.topicCooldown {
            return false
        }
        return true
    }

    /// The first-run "what should buzz?" sheet was answered (or skipped). Only
    /// the first call counts; it's never shown again after that.
    func recordFirstChoice(now: Date = .now) {
        guard date("alertNudge.firstChoice") == nil else { return }
        defaults.set(now.timeIntervalSince1970, forKey: "alertNudge.firstChoice")
    }

    var hasMadeFirstChoice: Bool { date("alertNudge.firstChoice") != nil }

    func recordAsked(_ topic: AlertNudge.Topic, now: Date = .now) {
        defaults.set(now.timeIntervalSince1970, forKey: "alertNudge.lastAsked")
        defaults.set(defaults.integer(forKey: key(topic, "count")) + 1, forKey: key(topic, "count"))
    }

    func recordAnswer(_ topic: AlertNudge.Topic, accepted: Bool, never: Bool, now: Date = .now) {
        if never { defaults.set(true, forKey: key(topic, "never")) }
        if !accepted { defaults.set(now.timeIntervalSince1970, forKey: key(topic, "declined")) }
    }

    // MARK: Storage

    private func key(_ topic: AlertNudge.Topic, _ field: String) -> String {
        "alertNudge.\(topic.rawValue).\(field)"
    }

    private func date(_ key: String) -> Date? {
        let seconds = defaults.double(forKey: key)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }
}
