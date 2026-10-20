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
    func fetchMyHeight() async throws -> HeightSetting
    /// A height to show, or hidden (a hidden height is never sent to anyone else).
    func setHeight(_ height: HeightSetting) async throws
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
    /// Implicit signals (watch time, rewatch, unmute…) that personalize ranking. Best effort.
    func logFeedEvents(_ events: [FeedEvent]) async
    func swipe(on userID: UUID, liked: Bool) async throws -> SwipeResult
    func capacityStatus() async throws -> CapacityStatus
    func likeQuota() async throws -> LikeQuota

    // MARK: Glimpse Gold
    func goldStatus() async throws -> GoldStatus
    /// Starts the weekly 30-minute Spotlight; returns when it ends.
    func startSpotlight() async throws -> Date
    /// Undoes your last pass and returns that person (nil when there's nothing to undo).
    func rewindLastPass() async throws -> FeedProfile?
    /// Appear in (and browse) another open city for 1–14 days; returns when the trip ends.
    func setTravel(latitude: Double, longitude: Double, city: String, days: Int) async throws -> Date
    func endTravel() async throws
    func clipInsights() async throws -> [ClipInsight]

    // MARK: Liked you (free for everyone)
    func likesReceived() async throws -> LikesReceived

    // MARK: Glimpse+
    /// Sends a StoreKit 2 signed transaction for server verification; returns whether Plus is active.
    func verifyPurchase(signedTransaction: String) async throws -> Bool

    // MARK: Connections
    func fetchMatches() async throws -> [MatchSummary]
    func unmatch(_ matchID: UUID) async throws
    func block(userID: UUID) async throws
    func report(userID: UUID, reason: ReportReason, details: String?, matchID: UUID?) async throws
    func setFrozen(_ matchID: UUID, frozen: Bool) async throws
    /// Pins are personal (the other person never sees them), up to 3.
    func setPinned(_ matchID: UUID, pinned: Bool) async throws
    func pinnedMatchIDs() async throws -> Set<UUID>
    func submitExitFeedback(matchID: UUID, reason: ExitReason) async throws

    // MARK: Coffee deals
    func dealsNear() async throws -> [Deal]
    func logDeal(_ dealID: UUID, kind: DealLogKind, near: Bool?, band: DistanceBand?) async
    /// Opens the live pass (or says why not). `near` is the phone's own check; nil = unknown.
    func openDeal(_ dealID: UUID, near: Bool?, band: DistanceBand) async throws -> DealOpenResult
    /// Staff tapped Redeem on the member's phone.
    func redeemDeal(passID: UUID) async throws -> DealRedeemResult
    /// Whether to offer a kind goodbye here (the server decides, and records the offer).
    func goodbyeOffer(matchID: UUID, context: GoodbyeContext) async throws -> GoodbyeOffer
    /// What they did with it; `.sent` closes the chat and delivers the note.
    func goodbyeRespond(promptID: UUID, action: GoodbyeAction, template: GoodbyeTemplate?, note: String?, edited: Bool) async throws
    func missedConnections() async throws -> [MissedConnection]
    func requestSecondChance(matchID: UUID) async throws
    func secondChances() async throws -> [SecondChance]
    func respondToSecondChance(_ id: UUID, accept: Bool) async throws -> SwipeResult

    // MARK: Chat
    func fetchMessages(matchID: UUID) async throws -> [ChatMessage]
    func send(_ body: String, matchID: UUID, replyTo: UUID?) async throws -> ChatMessage
    func fetchReactions(matchID: UUID) async throws -> [MessageReaction]
    /// One reaction per person per message; nil removes yours.
    func react(to messageID: UUID, emoji: String?) async throws
    /// Deletes one of your own messages for everyone (the safety team keeps a copy for 30 days).
    func deleteMessage(_ messageID: UUID) async throws
    /// Sends a voice message or video note recorded in the chat.
    func sendMedia(_ kind: MessageKind, fileURL: URL, duration: Double, matchID: UUID, replyTo: UUID?) async throws -> ChatMessage
    /// Playable links for chat recordings (only the two people in the conversation get them).
    func chatMediaURLs(for paths: [String]) async -> [String: URL]
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
    /// One 20-second piece of a Vibe Check safety recording. `received`: this phone's
    /// backup copy of the other person's video.
    func uploadVibeSegment(
        matchID: UUID, fileURL: URL, startedAt: Date, part: Int, duration: Double?, received: Bool
    ) async throws
    /// Whether this phone's backup copy is needed (their own recording missing, or a report).
    func vibeBackupDecision(matchID: UUID) async throws -> VibeBackupDecision

    /// Conversation topics from both profiles (the app adds general ones).
    func vibeTopics(matchID: UUID) async throws -> [String]

    // MARK: Date ideas (after a good Vibe Check)
    /// Nil until the match qualifies.
    func dateIdea(matchID: UUID) async throws -> DateIdea?
    func nextDateIdea(matchID: UUID) async throws -> DateIdea?
    func logDateIdea(_ ideaID: UUID, feedback: DateIdea.Feedback) async

    // MARK: Planned dates
    /// The plan in this chat: upcoming, or recent and waiting for my check-in.
    func plannedDate(matchID: UUID) async throws -> PlannedDate?
    func proposeDate(matchID: UUID, ideaID: UUID, at date: Date) async throws -> PlannedDate
    func respondDate(_ dateID: UUID, accept: Bool) async throws -> PlannedDate
    func cancelDate(_ dateID: UUID) async throws
    /// Moves the plan to a new time; the other person accepts again.
    func rescheduleDate(_ dateID: UUID, at date: Date) async throws -> PlannedDate
    func myPlannedDates() async throws -> [UpcomingDate]
    /// Private: did they show up?
    func checkInDate(_ dateID: UUID, outcome: DateOutcome) async throws

    /// A screenshot or screen-recording attempt during a call, for the safety team.
    func logVibeCapture(matchID: UUID, kind: String) async

    // MARK: Notifications
    func notifications() async throws -> [AppNotification]
    func markNotificationsRead(_ ids: [UUID]?) async throws
    func registerPushToken(_ token: String, environment: String) async throws
    func setPushScope(_ scope: PushScope) async throws
    /// The phone's language ("he" / "en"): what the server writes alerts and topics in.
    func setLocale(_ code: String) async
    /// Records agreement to the legal documents (proof, with the version).
    func recordConsents(_ kinds: [String], version: String, locale: String) async throws
    /// The latest terms version this member agreed to (nil if none on record).
    func myConsentVersion() async throws -> String?
    func setPushExtras(_ extras: [AlertExtra]) async throws
    /// Both are opt-in and off by default.
    func setDataConsent(aiTraining: Bool, sharing: Bool) async throws
    /// Turns the after-date question on or off.
    func setDateCheckins(_ enabled: Bool) async throws
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
    /// When it was filmed, from the file's metadata (uploads); nil = now.
    var capturedAt: Date?
}

extension GlimpseBackend {
    func send(_ body: String, matchID: UUID) async throws -> ChatMessage {
        try await send(body, matchID: matchID, replyTo: nil)
    }
}
