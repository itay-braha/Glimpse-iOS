import Foundation

/// A partner venue suggested as a first-date spot.
struct DateSpot: Codable, Hashable, Identifiable, Sendable {
    enum Category: String, Codable, Sendable {
        case cafe, bar, restaurant, dessert, activity, outdoors

        var symbol: String {
            switch self {
            case .cafe: "cup.and.saucer.fill"
            case .bar: "wineglass.fill"
            case .restaurant: "fork.knife"
            case .dessert: "birthday.cake.fill"
            case .activity: "figure.bowling"
            case .outdoors: "leaf.fill"
            }
        }

        var title: String {
            switch self {
            case .cafe: String(localized: "Café")
            case .bar: String(localized: "Bar")
            case .restaurant: String(localized: "Restaurant")
            case .dessert: String(localized: "Dessert")
            case .activity: String(localized: "Activity")
            case .outdoors: String(localized: "Outdoors")
            }
        }
    }

    let id: UUID
    let name: String
    let category: Category
    var tagline: String?
    var address: String?
    var city: String?
    let latitude: Double
    let longitude: Double
    var priceLevel: Int?
    /// As the venue gave them (text, since partner links aren't always well formed).
    var mapsURL: String?
    var website: String?
    var instagram: String?
    /// From me (the middle of the two of us is what picked it).
    var distanceKm: Double?

    var priceText: String? { priceLevel.map { String(repeating: "₪", count: $0) } }

    /// The venue's own map link, or a Google Maps search for it (opens the Google Maps
    /// app when installed, the browser otherwise).
    var mapsLink: URL? {
        mapsURL.flatMap { URL(string: $0) } ?? googleMapsURL
    }

    var googleMapsURL: URL? {
        var parts = URLComponents(string: "https://www.google.com/maps/search/")
        parts?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: [name, city].compactMap { $0 }.joined(separator: " ")),
        ]
        return parts?.url
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, tagline, address, city, latitude, longitude, website, instagram
        case priceLevel = "price_level"
        case mapsURL = "maps_url"
        case distanceKm = "distance_km"
    }
}
