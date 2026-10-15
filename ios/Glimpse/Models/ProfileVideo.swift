import Foundation

struct ProfileVideo: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var source: VideoSource
    var videoType: VideoType
    /// Object key in the `profile-videos` bucket (demo mode stores a full URL). Nil for embeds.
    var storagePath: String?
    var thumbnailPath: String?
    /// Canonical public post URL for embeds.
    var embedURL: URL?
    /// Known for hosted clips only; embeds play the platform's own length.
    var durationSeconds: Double?
    /// When the moment was published (social) or recorded (native). Server-verified.
    var capturedAt: Date
    /// Drives the mandatory "Added N days ago" tag and the 90-day rotation prompt.
    var importedAt: Date
    /// Optional vibe prompt shown over the clip (see `VibePrompt`).
    var promptKey: String?
    /// Normalized position of the owner in the frame ("It's me" tag), for group clips.
    var meMarkerX: Double?
    var meMarkerY: Double?

    init(
        id: UUID,
        source: VideoSource,
        videoType: VideoType = .hosted,
        storagePath: String?,
        thumbnailPath: String? = nil,
        embedURL: URL? = nil,
        durationSeconds: Double?,
        capturedAt: Date,
        importedAt: Date,
        promptKey: String? = nil,
        meMarkerX: Double? = nil,
        meMarkerY: Double? = nil
    ) {
        self.id = id
        self.source = source
        self.videoType = videoType
        self.storagePath = storagePath
        self.thumbnailPath = thumbnailPath
        self.embedURL = embedURL
        self.durationSeconds = durationSeconds
        self.capturedAt = capturedAt
        self.importedAt = importedAt
        self.promptKey = promptKey
        self.meMarkerX = meMarkerX
        self.meMarkerY = meMarkerY
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        source = try container.decode(VideoSource.self, forKey: .source)
        // Rows written before embeds existed have no type: they are hosted files.
        videoType = try container.decodeIfPresent(VideoType.self, forKey: .videoType) ?? .hosted
        storagePath = try container.decodeIfPresent(String.self, forKey: .storagePath)
        thumbnailPath = try container.decodeIfPresent(String.self, forKey: .thumbnailPath)
        embedURL = try container.decodeIfPresent(URL.self, forKey: .embedURL)
        durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
        capturedAt = try container.decode(Date.self, forKey: .capturedAt)
        importedAt = try container.decode(Date.self, forKey: .importedAt)
        promptKey = try container.decodeIfPresent(String.self, forKey: .promptKey)
        meMarkerX = try container.decodeIfPresent(Double.self, forKey: .meMarkerX)
        meMarkerY = try container.decodeIfPresent(Double.self, forKey: .meMarkerY)
    }

    var prompt: VibePrompt? { promptKey.flatMap(VibePrompt.init(rawValue:)) }
    var isEmbed: Bool { videoType == .embed }
    /// The parsed public link, for embeds.
    var embedLink: EmbedLink? { embedURL.flatMap { EmbedLink.parse($0.absoluteString) } }

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case videoType = "video_type"
        case storagePath = "storage_path"
        case thumbnailPath = "thumbnail_path"
        case embedURL = "embed_url"
        case durationSeconds = "duration_seconds"
        case capturedAt = "captured_at"
        case importedAt = "imported_at"
        case promptKey = "prompt_key"
        case meMarkerX = "me_marker_x"
        case meMarkerY = "me_marker_y"
    }
}
