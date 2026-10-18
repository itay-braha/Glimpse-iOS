import Foundation

enum ReportReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case harassment
    case ghosting
    case fakeProfile = "fake_profile"
    case inappropriateContent = "inappropriate_content"
    case underage
    case aiGenerated = "ai_generated"
    case spam
    case other

    var id: String { rawValue }

    /// Reasons the safety team acts on right away.
    var isUrgent: Bool {
        switch self {
        case .harassment, .inappropriateContent, .underage: true
        default: false
        }
    }

    var label: String {
        switch self {
        case .harassment: String(localized: "Harassment or threats")
        case .ghosting: String(localized: "Ghosted after matching")
        case .fakeProfile: String(localized: "Fake or impersonating")
        case .inappropriateContent: String(localized: "Inappropriate content")
        case .underage: String(localized: "May be under 18")
        case .aiGenerated: String(localized: "Looks AI-generated or deepfake")
        case .spam: String(localized: "Spam or scam")
        case .other: String(localized: "Something else")
        }
    }
}
