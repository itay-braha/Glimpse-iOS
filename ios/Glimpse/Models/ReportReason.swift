import Foundation

enum ReportReason: String, Codable, CaseIterable, Identifiable, Sendable {
    // Safety
    case sexualContent = "sexual_content"
    case harassment
    case unsafeInPerson = "unsafe_in_person"
    case underage
    // Identity
    case fakeProfile = "fake_profile"
    case aiGenerated = "ai_generated"
    // Commercial
    case selling
    case promotion
    case scam
    // Other
    case inappropriateContent = "inappropriate_content"
    case other
    // Kept for older reports; not offered (no-shows are asked about after a date instead).
    case ghosting
    case spam

    var id: String { rawValue }

    /// The menu, grouped. Deliberately no "not the gender they claim" (it invites reports
    /// against trans and nonbinary members; real catfishing is "fake profile") and no
    /// "only here for attention" (too subjective; behaviour is measured instead).
    static let menu: [(ReportCategory, [ReportReason])] = [
        (.safety, [.sexualContent, .harassment, .unsafeInPerson, .underage]),
        (.identity, [.fakeProfile, .aiGenerated]),
        (.commercial, [.selling, .promotion, .scam]),
        (.other, [.inappropriateContent, .other]),
    ]

    /// Reasons the safety team acts on right away.
    var isUrgent: Bool {
        switch self {
        case .sexualContent, .harassment, .unsafeInPerson, .underage, .inappropriateContent: true
        default: false
        }
    }

    var label: String {
        switch self {
        case .sexualContent: String(localized: "Sent sexual content")
        case .harassment: String(localized: "Harassing, threatening or creepy")
        case .unsafeInPerson: String(localized: "Made me feel unsafe in person")
        case .underage: String(localized: "May be under 18")
        case .fakeProfile: String(localized: "Fake profile, catfish or impersonation")
        case .aiGenerated: String(localized: "AI-generated or deepfake videos")
        case .selling: String(localized: "Selling content or followers (OnlyFans, Instagram…)")
        case .promotion: String(localized: "Promoting a business or event")
        case .scam: String(localized: "Scam, phishing or a bot")
        case .inappropriateContent: String(localized: "Inappropriate videos")
        case .other: String(localized: "Something else")
        case .ghosting: String(localized: "Ghosted after matching")
        case .spam: String(localized: "Spam")
        }
    }
}
