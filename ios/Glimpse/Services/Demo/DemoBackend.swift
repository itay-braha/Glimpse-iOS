import Foundation

/// In-memory backend for offline runs, previews, tests and CI screenshots.
/// Applies the same product rules as the database: the 20-match cap and the
/// stalest-first auto-boot.
actor DemoBackend: GlimpseBackend {
    nonisolated let isDemo = true
    static let demoCode = "123456"
    static let cap = 20

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
    private var replyCursor = 0
    private var isPlus = false
    private var likeTimes: [Date] = []
    private var admirers: [FeedProfile]
    private var revealedAdmirers: Set<UUID> = []
    private var lastFreeReveal: Date?
    private var notices: [AppNotification]
    private static let freeDailyLikes = 20
    private static let freeDailyViews = 50
    private var viewTimes: [Date] = []
    private var pausedUntil: Date?
    private var frozen: Set<UUID> = []
    private var missed: [MissedConnection]
    private var incomingSecondChances: [SecondChance]
    private var lastSecondChanceSent: Date?
    private var vibeStates: [UUID: VibeCheckState] = [:]
    /// Vibe Verified matches: 7-day immunity, separate from the user's freezes.
    private var immune: Set<UUID> = []

    /// - Parameter seeded: start signed in with a complete profile and 20 matches.
    init(seeded: Bool = true, now: Date = .now) {
        signedIn = seeded
        profile = seeded ? DemoData.myProfile() : nil
        videos = seeded ? DemoData.myVideos(now: now) : []
        candidates = DemoData.feed(now: now)
        matches = seeded ? DemoData.matches(now: now) : []
        let admirerList = DemoData.admirers(now: now)
        admirers = admirerList
        likedMe = DemoData.likedMe().union(admirerList.map(\.id))
        notices = seeded ? DemoData.notices(now: now) : []
        missed = seeded ? DemoData.missedConnections(now: now) : []
        incomingSecondChances = seeded ? [DemoData.secondChance(now: now)] : []
        for match in matches {
            messages[match.matchID] = DemoData.conversation(for: match, now: now)
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
        let video = ProfileVideo(
            id: UUID(),
            source: .native,
            storagePath: clip.fileURL.absoluteString,
            thumbnailPath: nil,
            durationSeconds: clip.durationSeconds,
            capturedAt: .now,
            importedAt: .now,
            promptKey: clip.promptKey
        )
        videos.insert(video, at: 0)
        profile?.isOnboarded = true
        return video
    }

    func deleteVideo(_ video: ProfileVideo) {
        videos.removeAll { $0.id == video.id }
        profile?.isOnboarded = !videos.isEmpty
    }

    func importInstagram(code: String) async throws -> [ProfileVideo] {
        try await Task.sleep(for: .milliseconds(800))
        let imported = DemoData.video(videos.count + 7, source: .instagram, importedDaysAgo: 0)
        videos.insert(imported, at: 0)
        profile?.isOnboarded = true
        return [imported]
    }

    // MARK: Discovery

    func fetchFeed(limit: Int) -> [FeedProfile] {
        if let pausedUntil, pausedUntil > .now { return [] }
        viewTimes.removeAll { Date.now.timeIntervalSince($0) > 86_400 }
        let remaining = max(viewAllowance - viewTimes.count, 0)
        return Array(candidates.filter { !swiped.contains($0.id) }.prefix(min(limit, remaining)))
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
            guard isPlus || likeTimes.count < Self.freeDailyLikes else { throw GlimpseError.outOfLikes }
            likeTimes.append(.now)
        }
        swiped.insert(userID)
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
            allowance: isPlus ? 300 : Self.freeDailyLikes,
            remaining: remainingLikes,
            resetsAt: isPlus ? nil : resets,
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
        isPlus ? 300 : max(Self.freeDailyLikes - likeTimes.count, 0)
    }

    private func pruneLikeTimes() {
        likeTimes.removeAll { Date.now.timeIntervalSince($0) > 86_400 }
    }

    // MARK: Liked you

    private var pendingAdmirers: [FeedProfile] {
        admirers.filter { !swiped.contains($0.id) }
    }

    private var freeRevealsLeft: Int {
        guard let lastFreeReveal else { return 1 }
        return Date.now.timeIntervalSince(lastFreeReveal) > 86_400 ? 1 : 0
    }

    func likesReceived() -> LikesReceived {
        let items = pendingAdmirers.enumerated().map { index, person in
            let visible = isPlus || revealedAdmirers.contains(person.id)
            return ReceivedLike(
                revealed: visible,
                likedAt: Date.now.addingTimeInterval(-Double(index + 1) * 5_400),
                age: visible ? nil : person.age,
                distanceKm: visible ? nil : person.distanceKm,
                isVerified: visible ? nil : person.isVerified,
                profile: visible ? person : nil
            )
        }
        return LikesReceived(
            total: items.count,
            isPlus: isPlus,
            freeRevealsLeft: isPlus ? nil : freeRevealsLeft,
            items: items
        )
    }

    func revealLike() throws -> FeedProfile? {
        guard isPlus || freeRevealsLeft > 0 else { throw GlimpseError.revealLimit }
        guard let next = pendingAdmirers.first(where: { !revealedAdmirers.contains($0.id) }) else { return nil }
        revealedAdmirers.insert(next.id)
        if !isPlus { lastFreeReveal = .now }
        return next
    }

    func verifyPurchase(signedTransaction: String) -> Bool {
        isPlus = true
        return true
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

    func setFrozen(_ matchID: UUID, frozen isFrozen: Bool) throws {
        if isFrozen {
            let active = Set(matches.map(\.matchID))
            guard frozen.intersection(active).subtracting([matchID]).count < freezeAllowance else {
                throw GlimpseError.freezeLimit
            }
            immune.insert(matchID)
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

    func send(_ body: String, matchID: UUID) -> ChatMessage {
        let message = ChatMessage(id: UUID(), matchID: matchID, senderID: me, body: body, createdAt: .now, readAt: nil)
        record(message)
        Task { await self.simulateReply(in: matchID) }
        return message
    }

    func markRead(matchID: UUID) {
        guard let index = matches.firstIndex(where: { $0.matchID == matchID }) else { return }
        matches[index].unreadCount = 0
    }

    func openChannel(matchID: UUID) -> ChatChannel {
        let (messageStream, messageContinuation) = AsyncStream.makeStream(of: ChatMessage.self)
        let (typingStream, typingContinuation) = AsyncStream.makeStream(of: Void.self)
        messageListeners[matchID] = messageContinuation
        typingListeners[matchID] = typingContinuation
        return ChatChannel(
            messages: messageStream,
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
        let mostRecent = matches.max { $0.lastActivity < $1.lastActivity }?.matchID == matchID
        let messageCount = match?.messageCount ?? 0
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
            frozen.insert(matchID)
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

    private func simulateReply(in matchID: UUID) async {
        try? await Task.sleep(for: .seconds(1.2))
        typingListeners[matchID]?.yield()
        try? await Task.sleep(for: .seconds(1.8))
        guard let match = matches.first(where: { $0.matchID == matchID }) else { return }
        let body = DemoData.replies[replyCursor % DemoData.replies.count]
        replyCursor += 1
        let reply = ChatMessage(id: UUID(), matchID: matchID, senderID: match.otherUserID, body: body, createdAt: .now, readAt: nil)
        record(reply)
        messageListeners[matchID]?.yield(reply)
    }

    private func closeChannel(_ matchID: UUID) {
        messageListeners.removeValue(forKey: matchID)?.finish()
        typingListeners.removeValue(forKey: matchID)?.finish()
    }
}
