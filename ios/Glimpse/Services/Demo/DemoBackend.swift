import Foundation

/// In-memory backend for offline runs, previews, tests and CI screenshots.
/// Applies the same product rules as the database: the 15-match cap and the
/// stalest-first auto-boot.
actor DemoBackend: GlimpseBackend {
    nonisolated let isDemo = true
    static let demoCode = "123456"
    static let cap = 15

    private let me = DemoData.meID
    private var signedIn: Bool
    private var profile: UserProfile?
    private var videos: [ProfileVideo]
    private var candidates: [FeedProfile]
    private var likedMe: Set<UUID>
    private var swiped: Set<UUID> = []
    private var matches: [MatchSummary]
    private var messages: [UUID: [ChatMessage]] = [:]
    private var messageListeners: [UUID: AsyncStream<ChatMessage>.Continuation] = [:]
    private var typingListeners: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var reactions: [UUID: [UUID: String]] = [:]
    private var reactionListeners: [UUID: AsyncStream<MessageReaction>.Continuation] = [:]
    private var replyCursor = 0
    private var isPlus = false
    private var isGold = false
    private var spotlightStarted: Date?
    private var passHistory: [UUID] = []
    private var rewindTimes: [Date] = []
    private var travel: (city: String, until: Date)?
    /// `-screen dateIdea`: every match is Vibe Verified.
    private let demoVibeVerified: Bool
    private var likeTimes: [Date] = []
    private var admirers: [FeedProfile]
    private var notices: [AppNotification]
    /// 10 likes a day for everyone, paid tiers included (private.daily_like_allowance).
    private static let freeDailyLikes = 10
    private static let freeDailyViews = 50
    private var viewTimes: [Date] = []
    private var pausedUntil: Date?
    private var frozen: Set<UUID> = []
    private var pinned: Set<UUID> = []
    private var missed: [MissedConnection]
    private var incomingSecondChances: [SecondChance]
    private var lastSecondChanceSent: Date?
    private var vibeStates: [UUID: VibeCheckState] = [:]
    /// Vibe Verified matches: 7-day immunity, separate from the user's freezes.
    private var immune: Set<UUID> = []

    /// - Parameter seeded: start signed in with a complete profile and 15 matches.
    /// `withVideos: false` starts signed in but before the first moment (onboarding's video hub).
    init(seeded: Bool = true, withVideos: Bool = true, vibeVerified: Bool = false, now: Date = .now) {
        demoVibeVerified = vibeVerified
        signedIn = seeded
        profile = seeded ? DemoData.myProfile() : nil
        videos = seeded && withVideos ? DemoData.myVideos(now: now) : []
        if seeded && !withVideos { profile?.isOnboarded = false }
        candidates = DemoData.feed(now: now)
        matches = seeded ? DemoData.matches(now: now) : []
        let admirerList = DemoData.admirers(now: now)
        admirers = admirerList
        likedMe = DemoData.likedMe().union(admirerList.map(\.id))
        notices = seeded ? DemoData.notices(now: now) : []
        missed = seeded ? DemoData.missedConnections(now: now) : []
        incomingSecondChances = seeded ? [DemoData.secondChance(now: now)] : []
        for match in matches {
            let conversation = DemoData.conversation(for: match, now: now)
            messages[match.matchID] = conversation
            // They loved your second message.
            if conversation.count > 1 {
                reactions[conversation[1].id] = [match.otherUserID: "❤️"]
            }
        }
    }

    // MARK: Auth & trust

    func restoreSession() -> UUID? {
        signedIn ? me : nil
    }

    func sendCode(to phone: String) async throws {
        try await Task.sleep(for: .milliseconds(400))
    }

    func verifyCode(_ code: String, phone: String) async throws -> UUID {
        try await Task.sleep(for: .milliseconds(400))
        guard code == Self.demoCode else { throw GlimpseError.invalidCode }
        signedIn = true
        return me
    }

    func attestDevice() -> DeviceVerdict {
        DeviceVerdict(allowed: true, verified: false, reason: nil)
    }

    func signOut() {
        signedIn = false
        profile = nil
        videos = []
        matches = []
        swiped = []
    }

    // MARK: Profile

    func fetchMyProfile() -> UserProfile? {
        profile
    }

    func createProfile(_ draft: ProfileDraft) -> UserProfile {
        let created = UserProfile(
            id: me,
            displayName: draft.displayName,
            birthdate: BirthdateFormat.string(from: draft.birthdate),
            gender: draft.gender,
            interestedIn: Gender.allCases.filter { draft.interestedIn.contains($0) },
            bio: draft.bio.isEmpty ? nil : draft.bio,
            city: draft.city.isEmpty ? nil : draft.city,
            ageMin: 18,
            ageMax: 40,
            isOnboarded: !videos.isEmpty,
            maxDistanceKm: 50,
            isVerified: false,
            verificationStatus: "none"
        )
        profile = created
        return created
    }

    func updateProfile(_ update: ProfileUpdate) {
        profile?.displayName = update.displayName
        profile?.bio = update.bio
        profile?.city = update.city
        profile?.interestedIn = update.interestedIn
        profile?.ageMin = update.ageMin
        profile?.ageMax = update.ageMax
        profile?.maxDistanceKm = update.maxDistanceKm
        profile?.flexibleDiscovery = update.flexibleDiscovery
    }

    func updateVideoDetails(_ videoID: UUID, promptKey: String?, meMarker: CGPoint?) {
        guard let index = videos.firstIndex(where: { $0.id == videoID }) else { return }
        videos[index].promptKey = promptKey
        videos[index].meMarkerX = meMarker.map { Double($0.x) }
        videos[index].meMarkerY = meMarker.map { Double($0.y) }
    }

    func accountState() -> AccountState {
        AccountState(
            status: "active",
            reason: nil,
            pausedUntil: (pausedUntil ?? .distantPast) > .now ? pausedUntil : nil,
            isPlus: isPlus
        )
    }

    func setPause(days: Int) -> Date? {
        guard days > 0 else {
            pausedUntil = nil
            return nil
        }
        pausedUntil = Date.now.addingTimeInterval(Double(min(days, 30)) * 86_400)
        return pausedUntil
    }

    func densityStatus() -> DensityStatus {
        .open
    }

    func reorderVideos(_ ids: [UUID]) {
        videos.sort { (ids.firstIndex(of: $0.id) ?? .max) < (ids.firstIndex(of: $1.id) ?? .max) }
    }

    func updateLocation(latitude: Double, longitude: Double) {}

    func deleteAccount() {
        signOut()
    }

    func fetchMyVideos() -> [ProfileVideo] {
        videos
    }

    func uploadClip(_ clip: RecordedClip) async throws -> ProfileVideo {
        try await Task.sleep(for: .milliseconds(600))
        if let filmed = clip.capturedAt, Recency.isTooOldToAdd(filmed) { throw GlimpseError.clipTooOld }
        let video = ProfileVideo(
            id: UUID(),
            source: clip.source,
            storagePath: clip.fileURL.absoluteString,
            thumbnailPath: nil,
            durationSeconds: clip.durationSeconds,
            capturedAt: clip.source == .upload ? min(clip.capturedAt ?? .now, .now) : .now,
            importedAt: .now,
            promptKey: clip.promptKey
        )
        videos.insert(video, at: 0)
        profile?.isOnboarded = true
        return video
    }

    func deleteVideo(_ video: ProfileVideo) throws {
        if !video.isEmbed, !videos.contains(where: { !$0.isEmbed && $0.id != video.id }) {
            throw GlimpseError.lastHostedClip
        }
        videos.removeAll { $0.id == video.id }
        profile?.isOnboarded = !videos.isEmpty
    }

    func addEmbed(_ link: EmbedLink, promptKey: String?) async throws -> ProfileVideo {
        try await Task.sleep(for: .milliseconds(500))
        if EmbedLink.isStory(link.canonicalURL.absoluteString) { throw GlimpseError.storyLink }
        guard videos.contains(where: { !$0.isEmbed }) else { throw GlimpseError.hostedFirst }
        if let posted = link.postDate, Recency.isTooOldToAdd(posted) { throw GlimpseError.clipTooOld }
        if videos.contains(where: { $0.source == link.platform.source && $0.embedURL == link.canonicalURL }) {
            throw GlimpseError.videoAlreadyAdded
        }
        let video = ProfileVideo(
            id: UUID(),
            source: link.platform.source,
            videoType: .embed,
            storagePath: nil,
            embedURL: link.canonicalURL,
            durationSeconds: nil,
            capturedAt: link.postDate ?? .now,
            importedAt: .now,
            promptKey: promptKey
        )
        // Links always sort after own clips, so the cover is never a link.
        videos.append(video)
        profile?.isOnboarded = true
        return video
    }

    func reportEmbedUnplayable(_ videoID: UUID) {}

    /// Kept so tests can see what the feed reports.
    private(set) var loggedFeedEvents: [FeedEvent] = []

    func logFeedEvents(_ events: [FeedEvent]) {
        loggedFeedEvents.append(contentsOf: events)
    }

    // MARK: Discovery

    func fetchFeed(limit: Int) -> [FeedProfile] {
        if let pausedUntil, pausedUntil > .now { return [] }
        viewTimes.removeAll { Date.now.timeIntervalSince($0) > 86_400 }
        let remaining = max(viewAllowance - viewTimes.count, 0)
        var pool = candidates.filter { !swiped.contains($0.id) }
        // Out of likes: people who already liked you first (liking back is free).
        if remainingLikes == 0 {
            pool = pool.filter { likedMe.contains($0.id) } + pool.filter { !likedMe.contains($0.id) }
        }
        return Array(pool.prefix(min(limit, remaining)))
    }

    func swipe(on userID: UUID, liked: Bool) throws -> SwipeResult {
        if let pausedUntil, pausedUntil > .now { throw GlimpseError.paused }
        // Daily limit on new profiles seen; answering an admirer never counts.
        if !likedMe.contains(userID) && !swiped.contains(userID) {
            viewTimes.removeAll { Date.now.timeIntervalSince($0) > 86_400 }
            guard viewTimes.count < viewAllowance else { throw GlimpseError.outOfViews }
            viewTimes.append(.now)
        }
        // Same freemium rule as the server: liking back an admirer is always free.
        if liked && !likedMe.contains(userID) {
            pruneLikeTimes()
            guard likeTimes.count < Self.freeDailyLikes else { throw GlimpseError.outOfLikes }
            likeTimes.append(.now)
        }
        swiped.insert(userID)
        if !liked { passHistory.append(userID) }
        let pool = candidates + admirers
        guard liked, likedMe.contains(userID), let person = pool.first(where: { $0.id == userID }) else {
            return SwipeResult(matched: false, matchID: nil, booted: nil, likesRemaining: remainingLikes)
        }

        var booted: BootedConnection?
        if matches.count >= Self.cap, let stalest = Staleness.rank(matches.filter { !isProtected($0) }).first {
            matches.removeAll { $0.matchID == stalest.matchID }
            messages[stalest.matchID] = nil
            booted = BootedConnection(matchID: stalest.matchID, userID: stalest.otherUserID, displayName: stalest.displayName)
            missed.insert(
                MissedConnection(
                    matchID: stalest.matchID,
                    userID: stalest.otherUserID,
                    displayName: stalest.displayName,
                    age: stalest.age,
                    thumbnailPath: stalest.thumbnailPath,
                    endedAt: .now,
                    secondChanceStatus: nil
                ),
                at: 0
            )
        }

        let match = MatchSummary(
            matchID: UUID(),
            otherUserID: person.id,
            displayName: person.displayName,
            age: person.age,
            city: person.city,
            thumbnailPath: nil,
            createdAt: .now,
            lastMessageAt: nil,
            messageCount: 0,
            lastMessageBody: nil,
            lastMessageMine: nil,
            unreadCount: 0,
            bootRank: 0
        )
        matches.append(match)
        messages[match.matchID] = []
        return SwipeResult(matched: true, matchID: match.matchID, booted: booted, likesRemaining: remainingLikes)
    }

    func likeQuota() -> LikeQuota {
        pruneLikeTimes()
        let resets = likeTimes.count >= Self.freeDailyLikes ? likeTimes.first.map { $0.addingTimeInterval(86_400) } : nil
        viewTimes.removeAll { Date.now.timeIntervalSince($0) > 86_400 }
        let viewsRemaining = max(viewAllowance - viewTimes.count, 0)
        return LikeQuota(
            allowance: Self.freeDailyLikes,
            remaining: remainingLikes,
            resetsAt: resets,
            isPlus: isPlus,
            viewsAllowance: viewAllowance,
            viewsRemaining: viewsRemaining,
            viewsResetAt: viewsRemaining == 0 ? viewTimes.first.map { $0.addingTimeInterval(86_400) } : nil
        )
    }

    private var viewAllowance: Int {
        isPlus ? 150 : Self.freeDailyViews
    }

    /// Mirrors private.is_protected: a freeze only shields a conversation that's still alive.
    private func isProtected(_ match: MatchSummary) -> Bool {
        immune.contains(match.matchID)
            || (frozen.contains(match.matchID) && Date.now.timeIntervalSince(match.lastActivity) < 14 * 86_400)
    }

    private var freezeAllowance: Int {
        isPlus ? 3 : 1
    }

    private var remainingLikes: Int {
        max(Self.freeDailyLikes - likeTimes.count, 0)
    }

    private func pruneLikeTimes() {
        likeTimes.removeAll { Date.now.timeIntervalSince($0) > 86_400 }
    }

    // MARK: Liked you

    private var pendingAdmirers: [FeedProfile] {
        admirers.filter { !swiped.contains($0.id) }
    }

    func likesReceived() -> LikesReceived {
        // Free for everyone: every admirer is shown.
        let items = pendingAdmirers.enumerated().map { index, person in
            ReceivedLike(
                revealed: true,
                likedAt: Date.now.addingTimeInterval(-Double(index + 1) * 5_400),
                age: nil,
                distanceKm: nil,
                isVerified: nil,
                profile: person
            )
        }
        return LikesReceived(total: items.count, isPlus: isPlus, freeRevealsLeft: nil, items: items)
    }

    /// "demo" unlocks Glimpse+, "demo-gold" unlocks Glimpse Gold (which includes Plus).
    func verifyPurchase(signedTransaction: String) -> Bool {
        isPlus = true
        if signedTransaction == "demo-gold" { isGold = true }
        return true
    }

    // MARK: Glimpse Gold

    private var rewindsLeft: Int {
        rewindTimes.removeAll { Date.now.timeIntervalSince($0) > 86_400 }
        return max(5 - rewindTimes.count, 0)
    }

    func goldStatus() -> GoldStatus {
        if let travel, travel.until < .now { self.travel = nil }
        let spotlightEnds = spotlightStarted.map { $0.addingTimeInterval(30 * 60) }
        let nextSpotlight = spotlightStarted.map { $0.addingTimeInterval(7 * 86_400) }
        return GoldStatus(
            isGold: isGold,
            spotlightUntil: spotlightEnds.flatMap { $0 > .now ? $0 : nil },
            spotlightAvailableAt: nextSpotlight.flatMap { $0 > .now ? $0 : nil },
            rewindsLeft: rewindsLeft,
            travelCity: travel?.city,
            travelUntil: travel?.until
        )
    }

    func startSpotlight() throws -> Date {
        guard isGold else { throw GlimpseError.goldRequired }
        if let spotlightStarted, Date.now.timeIntervalSince(spotlightStarted) < 7 * 86_400 {
            throw GlimpseError.spotlightUsed
        }
        spotlightStarted = .now
        return Date.now.addingTimeInterval(30 * 60)
    }

    func rewindLastPass() throws -> FeedProfile? {
        guard isGold else { throw GlimpseError.goldRequired }
        guard rewindsLeft > 0 else { throw GlimpseError.rewindLimit }
        guard let last = passHistory.popLast(), let person = candidates.first(where: { $0.id == last }) else { return nil }
        swiped.remove(last)
        rewindTimes.append(.now)
        return person
    }

    func setTravel(latitude: Double, longitude: Double, city: String, days: Int) throws -> Date {
        guard isGold else { throw GlimpseError.goldRequired }
        let until = Date.now.addingTimeInterval(Double(min(max(days, 1), 14)) * 86_400)
        travel = (city, until)
        return until
    }

    func endTravel() {
        travel = nil
    }

    /// Sample numbers for the demo profile's clips (the third hasn't been seen enough yet).
    func clipInsights() throws -> [ClipInsight] {
        guard isGold else { throw GlimpseError.goldRequired }
        let samples: [(Int, Double, Double, Int, Int)] = [(48, 0.71, 0.12, 9, 6), (31, 0.46, 0.33, 2, 2), (3, 0, 0, 0, 0)]
        return videos.enumerated().map { index, video in
            let sample = samples[min(index, samples.count - 1)]
            let enough = sample.0 >= 5
            return ClipInsight(
                videoID: video.id, viewers: sample.0, enoughData: enough,
                watchedThrough: enough ? sample.1 : nil, skipped: enough ? sample.2 : nil,
                moreTaps: enough ? sample.3 : nil, likes: enough ? sample.4 : nil
            )
        }
    }

    func capacityStatus() -> CapacityStatus {
        let next = matches.count >= Self.cap ? Staleness.rank(matches.filter { !isProtected($0) }).first : nil
        return CapacityStatus(
            active: matches.count,
            cap: Self.cap,
            atCapacity: matches.count >= Self.cap,
            nextToBoot: next.map {
                NextToBoot(
                    matchID: $0.matchID,
                    userID: $0.otherUserID,
                    displayName: $0.displayName,
                    lastActivityAt: $0.lastActivity,
                    messageCount: $0.messageCount
                )
            },
            freezesAllowed: freezeAllowance
        )
    }

    // MARK: Connections

    func fetchMatches() -> [MatchSummary] {
        let ranked = Staleness.rank(matches.filter { !isProtected($0) })
        let ranks = Dictionary(uniqueKeysWithValues: ranked.enumerated().map { ($1.matchID, $0 + 1) })
        return matches
            .map { match in
                var copy = match
                copy.bootRank = ranks[match.matchID]
                copy.isFrozen = frozen.contains(match.matchID)
                return copy
            }
            .sorted { $0.lastActivity > $1.lastActivity }
    }

    func unmatch(_ matchID: UUID) {
        matches.removeAll { $0.matchID == matchID }
    }

    func block(userID: UUID) {
        matches.removeAll { $0.otherUserID == userID }
        swiped.insert(userID)
    }

    func report(userID: UUID, reason: ReportReason, details: String?, matchID: UUID?) {
        block(userID: userID)
    }

    /// Mirrors public.set_pinned: up to 3, active matches only.
    func setPinned(_ matchID: UUID, pinned isPinned: Bool) throws {
        let active = Set(matches.map(\.matchID))
        guard active.contains(matchID) else { throw GlimpseError.message("That conversation has ended.") }
        if isPinned {
            guard pinned.intersection(active).subtracting([matchID]).count < 3 else { throw GlimpseError.pinLimit }
            pinned.insert(matchID)
        } else {
            pinned.remove(matchID)
        }
    }

    func pinnedMatchIDs() -> Set<UUID> {
        pinned.intersection(matches.map(\.matchID))
    }

    func setFrozen(_ matchID: UUID, frozen isFrozen: Bool) throws {
        if isFrozen {
            let active = Set(matches.map(\.matchID))
            guard frozen.intersection(active).subtracting([matchID]).count < freezeAllowance else {
                throw GlimpseError.freezeLimit
            }
            frozen.insert(matchID)
        } else {
            frozen.remove(matchID)
        }
    }

    func submitExitFeedback(matchID: UUID, reason: ExitReason) {}

    func missedConnections() -> [MissedConnection] {
        missed
    }

    func requestSecondChance(matchID: UUID) throws {
        guard isPlus else { throw GlimpseError.plusRequired }
        if let lastSecondChanceSent, Date.now.timeIntervalSince(lastSecondChanceSent) < 7 * 86_400 {
            throw GlimpseError.secondChanceLimit
        }
        guard let index = missed.firstIndex(where: { $0.matchID == matchID }) else { return }
        missed[index].secondChanceStatus = "pending"
        lastSecondChanceSent = .now
    }

    func secondChances() -> [SecondChance] {
        incomingSecondChances
    }

    func respondToSecondChance(_ id: UUID, accept: Bool) -> SwipeResult {
        guard let request = incomingSecondChances.first(where: { $0.id == id }) else {
            return SwipeResult(matched: false, matchID: nil, booted: nil)
        }
        incomingSecondChances.removeAll { $0.id == id }
        guard accept else { return SwipeResult(matched: false, matchID: nil, booted: nil) }

        var booted: BootedConnection?
        if matches.count >= Self.cap, let stalest = Staleness.rank(matches.filter { !isProtected($0) }).first {
            matches.removeAll { $0.matchID == stalest.matchID }
            booted = BootedConnection(matchID: stalest.matchID, userID: stalest.otherUserID, displayName: stalest.displayName)
        }
        let person = request.profile
        let match = MatchSummary(
            matchID: UUID(),
            otherUserID: person.id,
            displayName: person.displayName,
            age: person.age,
            city: person.city,
            thumbnailPath: nil,
            createdAt: .now,
            lastMessageAt: nil,
            messageCount: 0,
            lastMessageBody: nil,
            lastMessageMine: nil,
            unreadCount: 0,
            bootRank: nil
        )
        matches.append(match)
        messages[match.matchID] = []
        return SwipeResult(matched: true, matchID: match.matchID, booted: booted)
    }

    // MARK: Chat

    func fetchMessages(matchID: UUID) -> [ChatMessage] {
        messages[matchID] ?? []
    }

    func send(_ body: String, matchID: UUID, replyTo: UUID?) -> ChatMessage {
        var message = ChatMessage(id: UUID(), matchID: matchID, senderID: me, body: body, createdAt: .now, readAt: nil)
        message.replyTo = replyTo
        record(message)
        Task { await self.simulateReply(in: matchID, to: message) }
        return message
    }

    func fetchReactions(matchID: UUID) -> [MessageReaction] {
        reactions.flatMap { messageID, byUser in
            byUser.map { MessageReaction(messageID: messageID, userID: $0.key, matchID: matchID, emoji: $0.value) }
        }
        .filter { reaction in messages[matchID]?.contains { $0.id == reaction.messageID } == true }
    }

    func react(to messageID: UUID, emoji: String?) {
        reactions[messageID, default: [:]][me] = emoji
    }

    /// Kept like the server's evidence archive, so tests can check deleting doesn't erase.
    private(set) var deletedArchive: [UUID: ChatMessage] = [:]

    func deleteMessage(_ messageID: UUID) throws {
        for (matchID, list) in messages {
            guard let index = list.firstIndex(where: { $0.id == messageID }) else { continue }
            let message = list[index]
            guard message.senderID == me, !message.isUnsent
            else { throw GlimpseError.message("You can delete your own messages.") }
            deletedArchive[messageID] = message
            messages[matchID]?[index].deletedAt = .now
            messages[matchID]?[index].body = "Message deleted"
            messages[matchID]?[index].mediaPath = nil
            reactions[messageID] = nil
            return
        }
    }

    func sendMedia(_ kind: MessageKind, fileURL: URL, duration: Double, matchID: UUID, replyTo: UUID?) -> ChatMessage {
        var message = ChatMessage(
            id: UUID(), matchID: matchID, senderID: me,
            body: kind == .voice ? "🎤 Voice message" : "🎥 Video message", createdAt: .now, readAt: nil
        )
        message.kind = kind
        message.mediaPath = fileURL.absoluteString
        message.mediaDuration = min(duration, kind.maxDuration)
        message.replyTo = replyTo
        record(message)
        Task { await self.simulateReply(in: matchID, to: message) }
        return message
    }

    func chatMediaURLs(for paths: [String]) -> [String: URL] {
        mediaURLs(for: paths)
    }

    /// Demo calls have no camera, so there's nothing to keep.
    func uploadVibeSegment(
        matchID: UUID, fileURL: URL, startedAt: Date, part: Int, duration: Double?, received: Bool
    ) {}

    func vibeBackupDecision(matchID: UUID) -> VibeBackupDecision { .discard }

    // MARK: Vibe Check topics and date ideas

    func vibeTopics(matchID: UUID) -> [String] {
        let city = matches.first { $0.matchID == matchID }?.city ?? "Tel Aviv"
        return [
            "Ask about the best friend in their clip 🐶",
            "Their hot take: agree, or argue it out?",
            "Your favorite hidden spot in \(city)?",
        ]
    }

    private var dateIdeas: [UUID: [DateIdea]] = [:]

    /// Fictional demo venues (real partners come from the database).
    private static let demoSpots: [DateSpot] = [
        DateSpot(id: DemoData.id(9_001), name: "Lumen Café (demo)", category: .cafe, tagline: "Quiet corners, great light, better croissants",
                 address: "12 Example St", city: "Tel Aviv", latitude: 32.07, longitude: 34.775, priceLevel: 2, distanceKm: 1.2),
        DateSpot(id: DemoData.id(9_002), name: "Sunset Steps (demo)", category: .outdoors, tagline: "Sea view, bring a drink",
                 address: "The promenade", city: "Tel Aviv", latitude: 32.08, longitude: 34.766, priceLevel: 1, distanceKm: 2.0),
        DateSpot(id: DemoData.id(9_003), name: "Little Lantern Bar (demo)", category: .bar, tagline: "Low music, so you can actually talk",
                 address: "4 Sample Ave", city: "Tel Aviv", latitude: 32.06, longitude: 34.78, priceLevel: 2, distanceKm: 0.8),
    ]

    private func dateIdeaEligible(_ matchID: UUID) -> Bool {
        vibeStates[matchID]?.vibeVerified == true
            || matches.first { $0.matchID == matchID }?.vibeVerified == true
            || demoVibeVerified
    }

    func dateIdea(matchID: UUID) -> DateIdea? {
        guard dateIdeaEligible(matchID) else { return nil }
        if let latest = dateIdeas[matchID]?.last { return latest }
        return makeDateIdea(matchID)
    }

    func nextDateIdea(matchID: UUID) throws -> DateIdea? {
        guard dateIdeaEligible(matchID) else { return nil }
        guard (dateIdeas[matchID]?.count ?? 0) < 4 else { throw GlimpseError.ideaLimit }
        return makeDateIdea(matchID)
    }

    private func makeDateIdea(_ matchID: UUID) -> DateIdea {
        let used = Set((dateIdeas[matchID] ?? []).compactMap(\.spot?.id))
        let spot = Self.demoSpots.first { !used.contains($0.id) }
        let idea = DateIdea(id: UUID(), createdAt: .now, idea: spot == nil ? "A sunset walk, then ice cream on the way back" : nil, spot: spot)
        dateIdeas[matchID, default: []].append(idea)
        return idea
    }

    func logDateIdea(_ ideaID: UUID, feedback: DateIdea.Feedback) {}

    func logVibeCapture(matchID: UUID, kind: String) {}

    func setPushScope(_ scope: PushScope) {
        profile?.pushScope = scope
    }

    func setLocale(_ code: String) {}

    private var consentVersion: String? = LegalDocument.version

    func recordConsents(_ kinds: [String], version: String, locale: String) {
        consentVersion = version
    }

    func myConsentVersion() -> String? { consentVersion }

    func setPushExtras(_ extras: [AlertExtra]) {
        profile?.pushExtras = extras
    }

    func setDataConsent(aiTraining: Bool, sharing: Bool) {
        profile?.consentAiTraining = aiTraining
        profile?.consentDataSharing = sharing
    }

    func markRead(matchID: UUID) {
        guard let index = matches.firstIndex(where: { $0.matchID == matchID }) else { return }
        matches[index].unreadCount = 0
    }

    func openChannel(matchID: UUID) -> ChatChannel {
        let (messageStream, messageContinuation) = AsyncStream.makeStream(of: ChatMessage.self)
        let (updateStream, _) = AsyncStream.makeStream(of: ChatMessage.self)
        let (reactionStream, reactionContinuation) = AsyncStream.makeStream(of: MessageReaction.self)
        let (typingStream, typingContinuation) = AsyncStream.makeStream(of: Void.self)
        messageListeners[matchID] = messageContinuation
        reactionListeners[matchID] = reactionContinuation
        typingListeners[matchID] = typingContinuation
        return ChatChannel(
            messages: messageStream,
            updates: updateStream,
            reactions: reactionStream,
            typing: typingStream,
            sendTyping: {},
            close: { [weak self] in await self?.closeChannel(matchID) }
        )
    }

    // MARK: 3-Minute Vibe Check
    // Demo "me" is a man matched with women, so the women hold the key. The most
    // recent conversation has already been green-lit to show the full flow.

    func vibeCheck(matchID: UUID) -> VibeCheckState {
        if var state = vibeStates[matchID] {
            state.canJoin = state.status == .scheduled && state.confirmed
                && abs(state.scheduledAt?.timeIntervalSinceNow ?? .infinity) < 30 * 60
            vibeStates[matchID] = state
            return state
        }
        let match = matches.first { $0.matchID == matchID }
        let messageCount = match?.messageCount ?? 0
        // Showcase: the most recent established conversation has been green-lit.
        let mostRecent = messageCount >= 5
            && matches.filter { $0.messageCount >= 5 }.max { $0.lastActivity < $1.lastActivity }?.matchID == matchID
        let criteria = VibeCriteria(
            eligible: mostRecent || messageCount >= 20,
            messages: messageCount,
            balanced: true,
            days: messageCount >= 20 ? 3 : 1,
            recent: true,
            contactRequest: false,
            flagged: false
        )
        let state = VibeCheckState(
            status: mostRecent ? .femaleUnlocked : (criteria.eligible ? .eligible : .locked),
            iHoldKey: false,
            otherHoldsKey: true,
            showNudge: false,
            unlockedByOther: mostRecent,
            scheduledAt: nil,
            initiatedByMe: nil,
            confirmed: false,
            canJoin: false,
            startedAt: nil,
            vibeVerified: false,
            immunityUntil: nil,
            criteria: criteria
        )
        vibeStates[matchID] = state
        return state
    }

    func vibeGreenLight(matchID: UUID) {
        vibeStates[matchID]?.status = .femaleUnlocked
    }

    func vibePropose(matchID: UUID, at date: Date) {
        guard var state = vibeStates[matchID] else { return }
        state.status = .scheduled
        state.scheduledAt = date
        state.initiatedByMe = true
        state.confirmed = false
        vibeStates[matchID] = state
        // She accepts a moment later; the demo opens the lobby right away so the call can be tried.
        Task {
            try? await Task.sleep(for: .seconds(2))
            self.demoAccept(matchID)
        }
    }

    private func demoAccept(_ matchID: UUID) {
        vibeStates[matchID]?.confirmed = true
        vibeStates[matchID]?.scheduledAt = .now
    }

    func vibeRespond(matchID: UUID, accept: Bool) {
        if accept {
            vibeStates[matchID]?.confirmed = true
        } else {
            vibeStates[matchID]?.status = .femaleUnlocked
            vibeStates[matchID]?.scheduledAt = nil
        }
    }

    func vibeDismissNudge(matchID: UUID) {
        vibeStates[matchID]?.showNudge = false
    }

    func vibeMarkStarted(matchID: UUID) -> VibeClock {
        let start = vibeStates[matchID]?.startedAt ?? .now
        vibeStates[matchID]?.startedAt = start
        return VibeClock(startedAt: start, endsAt: start.addingTimeInterval(180), serverNow: .now)
    }

    func vibeSubmitResult(matchID: UUID, outcome: VibeOutcome) -> Bool {
        let verified = outcome == .matched // the demo partner always felt it too
        vibeStates[matchID]?.status = outcome == .report ? .disabled : .completed
        vibeStates[matchID]?.vibeVerified = verified
        if verified {
            vibeStates[matchID]?.immunityUntil = Date.now.addingTimeInterval(7 * 86_400)
            immune.insert(matchID)
        }
        return verified
    }

    func vibeIceServers(matchID: UUID) -> [IceServerConfig] {
        [IceServerConfig(urls: ["stun:stun.l.google.com:19302"])]
    }

    /// Loopback signaling: the demo partner answers "ready" a moment after you do.
    func openVibeSignaling(matchID: UUID) -> VibeSignalChannel {
        let (stream, continuation) = AsyncStream.makeStream(of: VibeSignal.self)
        return VibeSignalChannel(
            signals: stream,
            send: { signal in
                guard signal.kind == .ready else { return }
                try? await Task.sleep(for: .milliseconds(1_200))
                continuation.yield(VibeSignal(kind: .ready, sender: "demo-partner"))
            },
            close: { continuation.finish() }
        )
    }

    // MARK: Notifications

    func notifications() -> [AppNotification] {
        notices
    }

    func markNotificationsRead(_ ids: [UUID]?) {
        for index in notices.indices where ids == nil || ids?.contains(notices[index].id) == true {
            notices[index].readAt = .now
        }
    }

    func registerPushToken(_ token: String, environment: String) {}

    func unregisterPushToken(_ token: String) {}

    // MARK: Verification

    func startVerification() -> VerificationChallenge {
        VerificationChallenge(id: UUID(), gesture: "Hold up three fingers next to your face")
    }

    func submitVerification(_ challenge: VerificationChallenge, clip: RecordedClip) async throws {
        try await Task.sleep(for: .milliseconds(500))
        profile?.verificationStatus = "pending"
    }

    // MARK: Telemetry

    func track(_ event: String, properties: [String: String]) {}

    func reportDiagnostic(kind: String, payload: Data, appVersion: String?) {}

    // MARK: Media

    func mediaURLs(for paths: [String]) -> [String: URL] {
        var result: [String: URL] = [:]
        for path in paths {
            if let url = URL(string: path) { result[path] = url }
        }
        return result
    }

    // MARK: Simulation

    private func record(_ message: ChatMessage) {
        messages[message.matchID, default: []].append(message)
        if let index = matches.firstIndex(where: { $0.matchID == message.matchID }) {
            matches[index].lastMessageAt = message.createdAt
            matches[index].messageCount += 1
            matches[index].lastMessageBody = message.body
            matches[index].lastMessageMine = message.senderID == me
        }
    }

    /// The demo match reacts ❤️ to what you sent, then answers (quoting you every other time).
    private func simulateReply(in matchID: UUID, to sent: ChatMessage) async {
        try? await Task.sleep(for: .seconds(1.2))
        guard let match = matches.first(where: { $0.matchID == matchID }) else { return }
        let heart = MessageReaction(messageID: sent.id, userID: match.otherUserID, matchID: matchID, emoji: "❤️")
        reactions[sent.id, default: [:]][match.otherUserID] = "❤️"
        reactionListeners[matchID]?.yield(heart)
        typingListeners[matchID]?.yield()
        try? await Task.sleep(for: .seconds(1.8))
        let body = DemoData.replies[replyCursor % DemoData.replies.count]
        var reply = ChatMessage(id: UUID(), matchID: matchID, senderID: match.otherUserID, body: body, createdAt: .now, readAt: nil)
        if replyCursor.isMultiple(of: 2) { reply.replyTo = sent.id }
        replyCursor += 1
        record(reply)
        messageListeners[matchID]?.yield(reply)
    }

    private func closeChannel(_ matchID: UUID) {
        messageListeners.removeValue(forKey: matchID)?.finish()
        reactionListeners.removeValue(forKey: matchID)?.finish()
        typingListeners.removeValue(forKey: matchID)?.finish()
    }
}
