import Foundation

/// Discovery widens gently when everyone inside someone's filters has been seen,
/// and says so on the card instead of pretending it's a perfect fit.
enum DiscoveryNote: String, Codable, Sendable {
    case widerDistance = "wider_distance"
    case outsideAge = "outside_age"
    case secondLook = "second_look"
    case other

    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = DiscoveryNote(rawValue: raw) ?? .other
    }

    var text: String {
        switch self {
        case .widerDistance: String(localized: "A little further than usual")
        case .outsideAge: String(localized: "Just outside your age range")
        case .secondLook: String(localized: "Second look · new moments")
        case .other: String(localized: "Suggested for you")
        }
    }

    var symbol: String {
        switch self {
        case .widerDistance: "location.circle"
        case .outsideAge: "person.2"
        case .secondLook: "arrow.counterclockwise"
        case .other: "sparkles"
        }
    }
}
