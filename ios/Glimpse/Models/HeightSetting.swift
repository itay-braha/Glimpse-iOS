import Foundation

/// My height and whether it's on my card. A hidden height stays on the server only.
struct HeightSetting: Codable, Hashable, Sendable {
    var heightCm: Int?
    var isShown: Bool
    /// False until the member has answered (given a height or chosen to hide it).
    var isSet: Bool = true

    static let range = 120...230
    /// Where the picker opens when nothing is chosen yet.
    static let pickerStart = 170

    static let unanswered = HeightSetting(heightCm: nil, isShown: false, isSet: false)

    /// "178 cm"
    static func label(_ cm: Int) -> String {
        String(localized: "\(cm) cm")
    }

    enum CodingKeys: String, CodingKey {
        case heightCm = "height_cm"
        case isShown = "is_shown"
        case isSet = "is_set"
    }
}
