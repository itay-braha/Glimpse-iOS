import Foundation

enum VideoSource: String, Codable, Sendable {
    case instagram
    case tiktok
    case native

    var displayName: String {
        switch self {
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .native: "Recorded on Glimpse"
        }
    }

    var symbolName: String {
        switch self {
        case .instagram: "camera.aperture"
        case .tiktok: "music.note"
        case .native: "video.fill"
        }
    }
}
