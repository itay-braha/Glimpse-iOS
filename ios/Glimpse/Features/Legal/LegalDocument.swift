import Foundation

/// In-app legal texts, in Hebrew or English by the phone's language (Hebrew prevails
/// for users in Israel). The documents live in `Legal/*.{he,en}.md`; the operator,
/// contact, date and version are filled in here, so a change of operator (for
/// example, once the company is registered) is one edit. Have them reviewed by an
/// Israeli lawyer before launch.
enum LegalDocument: String, Identifiable, CaseIterable {
    case terms
    case privacy
    case communityRules = "community"
    case safety
    case accessibility

    /// Bump on every material change: members are asked to accept again.
    static let version = "2026-10-18"
    static let contactEmail = "support@lugipod.com"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: String(localized: "Terms of Service")
        case .privacy: String(localized: "Privacy Policy")
        case .communityRules: String(localized: "Community Rules")
        case .safety: String(localized: "Safety Tips")
        case .accessibility: String(localized: "Accessibility Statement")
        }
    }

    private static var isHebrew: Bool { ConsentStore.languageCode == "he" }

    private static var operatorName: String {
        isHebrew
            ? "‏Itay Braha (ישראל), המפעיל את Glimpse עד לרישום החברה"
            : "Itay Braha (Israel), who operates Glimpse until its company is registered"
    }

    private static var updated: String {
        let date = ISO8601DateFormatter().date(from: version + "T12:00:00Z") ?? .now
        return date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: isHebrew ? "he_IL" : "en_US")))
    }

    /// Lightweight markdown: "## " lines are headings, blank lines split paragraphs, **bold** inline.
    var body: String {
        let language = Self.isHebrew ? "he" : "en"
        let url = Bundle.main.url(forResource: "\(rawValue).\(language)", withExtension: "md")
            ?? Bundle.main.url(forResource: "\(rawValue).en", withExtension: "md")
        let text = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            ?? String(localized: "This document couldn't be loaded. Contact \(Self.contactEmail).")
        return text
            .replacingOccurrences(of: "{{OPERATOR}}", with: Self.operatorName)
            .replacingOccurrences(of: "{{EMAIL}}", with: Self.contactEmail)
            .replacingOccurrences(of: "{{UPDATED}}", with: Self.updated)
            .replacingOccurrences(of: "{{VERSION}}", with: Self.version)
    }
}
