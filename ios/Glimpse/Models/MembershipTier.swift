import Foundation

/// The two paid tiers. Gold includes everything in Glimpse+.
enum MembershipTier: String, CaseIterable, Identifiable, Sendable {
    case plus
    case gold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plus: "Glimpse+"
        case .gold: "Glimpse Gold"
        }
    }

    var productIDs: [String] {
        switch self {
        case .plus: ["com.itaybraha.glimpse.plus.monthly", "com.itaybraha.glimpse.plus.yearly"]
        case .gold: ["com.itaybraha.glimpse.gold.monthly", "com.itaybraha.glimpse.gold.yearly"]
        }
    }

    /// Placeholder until prices are set in App Store Connect.
    var placeholderPrice: String {
        switch self {
        case .plus: "$9.99 a month"
        case .gold: "$24.99 a month"
        }
    }

    /// What the server calls this plan (`verify-purchase` answers with it).
    init?(plan: String) {
        self.init(rawValue: plan)
    }
}
