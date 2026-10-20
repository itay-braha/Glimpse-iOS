import Foundation

/// How far the phone is from a place, in rough bands. Only the band (and "near") is
/// sent; the exact position never leaves the phone.
enum DistanceBand: String, Codable, Sendable {
    case under100 = "0-100"
    case under300 = "100-300"
    case under1km = "300-1000"
    case farther = "1000+"
    case unknown

    /// Close enough to count as being there.
    static let nearMeters: Double = 200

    init(meters: Double?) {
        guard let meters else { self = .unknown; return }
        switch meters {
        case ..<100: self = .under100
        case ..<300: self = .under300
        case ..<1_000: self = .under1km
        default: self = .farther
        }
    }
}
