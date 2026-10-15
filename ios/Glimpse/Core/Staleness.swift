import Foundation

/// Mirrors `private.match_staleness` in the database: hours since the last
/// interaction, damped by how much the two people have talked. Higher = staler.
/// The server is authoritative; the client uses this for previews and demo mode.
enum Staleness {
    static func score(lastActivity: Date, messageCount: Int, now: Date = .now) -> Double {
        let hours = max(0, now.timeIntervalSince(lastActivity)) / 3600
        return hours / (1 + log(1 + Double(max(messageCount, 0))))
    }

    /// Orders matches from stalest to freshest, breaking ties by age.
    static func rank(_ matches: [MatchSummary], now: Date = .now) -> [MatchSummary] {
        matches.sorted { lhs, rhs in
            let l = score(lastActivity: lhs.lastActivity, messageCount: lhs.messageCount, now: now)
            let r = score(lastActivity: rhs.lastActivity, messageCount: rhs.messageCount, now: now)
            if l != r { return l > r }
            return lhs.createdAt < rhs.createdAt
        }
    }
}
