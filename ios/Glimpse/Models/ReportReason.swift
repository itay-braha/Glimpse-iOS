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

    var label: String {
        switch self {
        case .harassment: "Harassment or threats"
        case .ghosting: "Ghosted after matching"
        case .fakeProfile: "Fake or impersonating"
        case .inappropriateContent: "Inappropriate content"
        case .underage: "May be under 18"
        case .aiGenerated: "Looks AI-generated or deepfake"
        case .spam: "Spam or scam"
        case .other: "Something else"
        }
    }
}
