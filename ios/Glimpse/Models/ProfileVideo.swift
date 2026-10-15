import Foundation

struct ProfileVideo: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var source: VideoSource
    /// Object key in the `profile-videos` bucket (demo mode stores a full URL).
    var storagePath: String
    var thumbnailPath: String?
    var durationSeconds: Double
    /// When the moment was published (social) or recorded (native). Server-verified.
    var capturedAt: Date
    /// Drives the mandatory "Imported N days ago" tag and the 90-day rotation prompt.
    var importedAt: Date
    /// Optional vibe prompt shown over the clip (see `VibePrompt`).
    var promptKey: String?
    /// Normalized position of the owner in the frame ("It's me" tag), for group clips.
    var meMarkerX: Double?
    var meMarkerY: Double?

    var prompt: VibePrompt? { promptKey.flatMap(VibePrompt.init(rawValue:)) }

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case storagePath = "storage_path"
        case thumbnailPath = "thumbnail_path"
        case durationSeconds = "duration_seconds"
        case capturedAt = "captured_at"
        case importedAt = "imported_at"
        case promptKey = "prompt_key"
        case meMarkerX = "me_marker_x"
        case meMarkerY = "me_marker_y"
    }
}
