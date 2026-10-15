import Foundation

enum VideoSource: String, Codable, Sendable {
    case instagram
    case tiktok
    /// Recorded in the Glimpse camera.
    case native
    /// Picked from the camera roll ("Quick upload").
    case upload

    var displayName: String {
        switch self {
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .native: "Recorded on Glimpse"
        case .upload: "Uploaded"
        }
    }

    var symbolName: String {
        switch self {
        case .instagram: "camera.aperture"
        case .tiktok: "music.note"
        case .native: "video.fill"
        case .upload: "photo.on.rectangle"
        }
    }
}

/// How a moment is stored and played.
enum VideoType: String, Codable, Sendable {
    /// A file Glimpse hosts privately (recorded or uploaded). Plays in our own looping player.
    case hosted
    /// A public Instagram / TikTok post, played through the platform's official embed.
    case embed
}
