import Foundation

enum Gender: String, Codable, CaseIterable, Identifiable, Sendable {
    case woman
    case man
    case nonbinary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .woman: String(localized: "Woman")
        case .man: String(localized: "Man")
        case .nonbinary: String(localized: "Nonbinary")
        }
    }

    var pluralLabel: String {
        switch self {
        case .woman: String(localized: "Women")
        case .man: String(localized: "Men")
        case .nonbinary: String(localized: "Nonbinary people")
        }
    }
}
