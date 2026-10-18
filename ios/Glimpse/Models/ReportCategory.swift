import Foundation

/// Groups in the report menu.
enum ReportCategory: String, Sendable {
    case safety
    case identity
    case commercial
    case other

    var title: String {
        switch self {
        case .safety: String(localized: "Safety and harassment")
        case .identity: String(localized: "Identity and fraud")
        case .commercial: String(localized: "Selling and spam")
        case .other: String(localized: "Something else")
        }
    }
}
