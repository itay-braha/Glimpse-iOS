import Foundation

enum Gender: String, Codable, CaseIterable, Identifiable, Sendable {
    case woman
    case man
    case nonbinary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .woman: "Woman"
        case .man: "Man"
        case .nonbinary: "Nonbinary"
        }
    }

    var pluralLabel: String {
        switch self {
        case .woman: "Women"
        case .man: "Men"
        case .nonbinary: "Nonbinary people"
        }
    }
}
