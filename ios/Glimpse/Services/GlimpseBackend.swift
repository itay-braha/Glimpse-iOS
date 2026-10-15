import Foundation

/// Everything the app needs from the server. `SupabaseBackend` talks to the real
/// project; `DemoBackend` is an in-memory stand-in used when no project is
/// configured (offline runs, previews, CI screenshots).
protocol GlimpseBackend: AnyObject, Sendable {
    var isDemo: Bool { get }

    // MARK: Auth & trust
    func restoreSession() async -> UUID?
    func sendCode(to phone: String) async throws
    func verifyCode(_ code: String, phone: String) async throws -> UUID
    func attestDevice() async throws -> DeviceVerdict
    func signOut() async

    // MARK: Profile
    func fetchMyProfile() async throws -> UserProfile?
    func createProfile(_ draft: ProfileDraft) async throws -> UserProfile
    func updateProfile(_ update: ProfileUpdate) async throws
    func fetchMyVideos() async throws -> [ProfileVideo]
    func uploadClip(_ clip: RecordedClip) async throws -> ProfileVideo
    func deleteVideo(_ video: ProfileVideo) async throws
    /// Links a public Instagram / TikTok post. The server validates and canonicalizes the URL.
    func addEmbed(_ link: EmbedLink, promptKey: String?) async throws -> ProfileVideo
    /// Silent signal from a viewer's phone: this linked post showed nothing.
    func reportEmbedUnplayable(_ videoID: UUID) async
    /// Persists clip order; the first clip is the cover.
    func reorderVideos(_ ids: [UUID]) async throws
    func updateLocation(latitude: Double, longitude: Double) async throws
    func deleteAccount() async throws
    func updateVideoDetails(_ videoID: UUID, promptKey: String?, meMarker: CGPoint?) async throws

    // MARK: Account state
    func accountState() async throws -> AccountState
    /// Pauses for 1-30 days (0 resumes). Returns when the pause ends.
    func setPause(days: Int) async throws -> Date?
    func densityStatus() async throws -> DensityStatus

    // MARK: Discovery
    func fetchFeed(limit: Int) async throws -> [FeedProfile]
    func swipe(on userID: UUID, liked: Bool) async throws -> SwipeResult
    func capacityStatus() async throws -> CapacityStatus
    func likeQuota() async throws -> LikeQuota

    // MARK: Liked you (freemium)
    func likesReceived() async throws -> LikesReceived
    /// Uses the daily free reveal (Glimpse+ doesn't need it). Nil when nobody is hidden.
    func revealLike() async throws -> FeedProfile?

    // MARK: Glimpse+
    /// Sends a StoreKit 2 signed transaction for server verification; returns whether Plus is active.
    func verifyPurchase(signedTransaction: String) async throws -> Bool

    // MARK: Connections
    func fetchMatches() async throws -> [MatchSummary]
    func unmatch(_ matchID: UUID) async throws
    func block(userID: UUID) async throws
    func report(userID: UUID, reason: ReportReason, details: String?, matchID: UUID?) async throws
    func setFrozen(_ matchID: UUID, frozen: Bool) async throws
    func submitExitFeedback(matchID: UUID, reason: ExitReason) async throws
    func missedConnections() async throws -> [MissedConnection]
    func requestSecondChance(matchID: UUID) async throws
    func secondChances() async throws -> [SecondChance]
    func respondToSecondChance(_ id: UUID, accept: Bool) async throws -> SwipeResult

    // MARK: Chat
    func fetchMessages(matchID: UUID) async throws -> [ChatMessage]
    func send(_ body: String, matchID: UUID) async throws -> ChatMessage
    func markRead(matchID: UUID) async throws
    func openChannel(matchID: UUID) async -> ChatChannel

    // MARK: 3-Minute Vibe Check
    func vibeCheck(matchID: UUID) async throws -> VibeCheckState
    func vibeGreenLight(matchID: UUID) async throws
    func vibePropose(matchID: UUID, at date: Date) async throws
    func vibeRespond(matchID: UUID, accept: Bool) async throws
    func vibeDismissNudge(matchID: UUID) async throws
    func vibeMarkStarted(matchID: UUID) async throws -> VibeClock
    /// Returns true when both people said the vibe matched.
    func vibeSubmitResult(matchID: UUID, outcome: VibeOutcome) async throws -> Bool
    func vibeIceServers(matchID: UUID) async throws -> [IceServerConfig]
    func openVibeSignaling(matchID: UUID) async -> VibeSignalChannel

    // MARK: Notifications
    func notifications() async throws -> [AppNotification]
    func markNotificationsRead(_ ids: [UUID]?) async throws
    func registerPushToken(_ token: String, environment: String) async throws
    func unregisterPushToken(_ token: String) async

    // MARK: Verification
    func startVerification() async throws -> VerificationChallenge
    func submitVerification(_ challenge: VerificationChallenge, clip: RecordedClip) async throws

    // MARK: Telemetry (first-party, best effort)
    func track(_ event: String, properties: [String: String]) async
    func reportDiagnostic(kind: String, payload: Data, appVersion: String?) async

    // MARK: Media
    /// Resolves storage paths to playable URLs (signed, short-lived in production).
    func mediaURLs(for paths: [String]) async -> [String: URL]
}

/// A compressed clip ready for upload.
struct RecordedClip: Sendable {
    let fileURL: URL
    let durationSeconds: Double
    let thumbnailJPEG: Data?
    var promptKey: String?
    /// `.native` from the camera, `.upload` from the camera roll.
    var source: VideoSource = .native
    var byteCount: Int?
}
