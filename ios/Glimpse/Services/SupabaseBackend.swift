import Foundation
import Supabase

/// Production backend. All match-graph mutations go through Postgres RPCs so the
/// 15-match cap and auto-boot run inside one locked transaction on the server.
final class SupabaseBackend: GlimpseBackend {
    let isDemo = false
    let config: AppConfig

    private let client: SupabaseClient
    private let signedURLs = SignedURLCache()

    init(config: AppConfig) {
        self.config = config
        client = SupabaseClient(supabaseURL: config.supabaseURL, supabaseKey: config.supabaseKey)
    }

    private func currentUserID() throws -> UUID {
        guard let id = client.auth.currentUser?.id else { throw GlimpseError.notSignedIn }
        return id
    }

    private func currentUserKey() throws -> String {
        try currentUserID().uuidString.lowercased()
    }

    // MARK: Auth & trust

    func restoreSession() async -> UUID? {
        try? await client.auth.session.user.id
    }

    func sendCode(to phone: String) async throws {
        try await client.auth.signInWithOTP(phone: phone)
    }

    func verifyCode(_ code: String, phone: String) async throws -> UUID {
        let response = try await client.auth.verifyOTP(phone: phone, token: code, type: .sms)
        switch response {
        case let .session(session): return session.user.id
        case let .user(user): return user.id
        }
    }

    func attestDevice() async throws -> DeviceVerdict {
        let payload = await DeviceAttestation.payload()
        return try await client.functions.invoke(
            "device-check",
            options: FunctionInvokeOptions(body: payload)
        )
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    // MARK: Profile

    func fetchMyProfile() async throws -> UserProfile? {
        let rows: [UserProfile] = try await client.from("profiles")
            .select()
            .eq("id", value: currentUserKey())
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func createProfile(_ draft: ProfileDraft) async throws -> UserProfile {
        let row = NewProfileRow(
            id: try currentUserKey(),
            displayName: draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            birthdate: BirthdateFormat.string(from: draft.birthdate),
            gender: draft.gender,
            interestedIn: Gender.allCases.filter { draft.interestedIn.contains($0) },
            bio: draft.bio.isEmpty ? nil : draft.bio,
            city: draft.city.isEmpty ? nil : draft.city
        )
        let profile: UserProfile = try await client.from("profiles").insert(row).select().single().execute().value
        try await setHeight(draft.height)
        return profile
    }

    func fetchMyHeight() async throws -> HeightSetting {
        try await client.rpc("my_height").execute().value
    }

    func setHeight(_ height: HeightSetting) async throws {
        try await client.rpc("set_height", params: HeightParams(heightCm: height.heightCm, show: height.isShown)).execute()
    }

    func updateProfile(_ update: ProfileUpdate) async throws {
        try await client.from("profiles")
            .update(update)
            .eq("id", value: currentUserKey())
            .execute()
    }

    func fetchMyVideos() async throws -> [ProfileVideo] {
        try await client.from("profile_videos")
            .select()
            .eq("user_id", value: currentUserKey())
            .order("position")
            .order("imported_at", ascending: false)
            .execute()
            .value
    }

    func uploadClip(_ clip: RecordedClip) async throws -> ProfileVideo {
        let owner = try currentUserKey()
        let videoPath = try await upload(fileURL: clip.fileURL, kind: "profile", ext: "mp4", bytes: clip.byteCount)

        var thumbnailPath: String?
        if let jpeg = clip.thumbnailJPEG {
            thumbnailPath = try? await upload(data: jpeg, kind: "profile", ext: "jpg")
        }

        let row = NewVideoRow(
            userID: owner,
            source: clip.source == .upload ? .upload : .native,
            storagePath: videoPath,
            thumbnailPath: thumbnailPath,
            durationSeconds: (clip.durationSeconds * 100).rounded() / 100,
            promptKey: clip.promptKey,
            capturedAt: clip.capturedAt
        )
        do {
            return try await client.from("profile_videos").insert(row).select().single().execute().value
        } catch let error as PostgrestError where error.message == "too_old" {
            throw GlimpseError.clipTooOld
        }
    }

    func updateVideoDetails(_ videoID: UUID, promptKey: String?, meMarker: CGPoint?) async throws {
        let details = VideoDetailsRow(
            promptKey: promptKey,
            meMarkerX: meMarker.map { Double($0.x) },
            meMarkerY: meMarker.map { Double($0.y) }
        )
        try await client.from("profile_videos").update(details).eq("id", value: videoID.uuidString).execute()
    }

    /// Asks the media function for a one-time upload URL, then PUTs the bytes there.
    private func upload(
        fileURL: URL? = nil, data: Data? = nil, kind: String, ext: String, bytes: Int? = nil,
        limit: Int = VideoCompressor.maxBytes
    ) async throws -> String {
        let size = bytes ?? data?.count
        if let size, size > limit { throw GlimpseError.videoTooLarge }
        let ticket: UploadTicket = try await client.functions.invoke(
            "media",
            options: FunctionInvokeOptions(body: UploadTicketRequest(kind: kind, ext: ext, bytes: size))
        )
        guard let url = URL(string: ticket.uploadURL) else { throw GlimpseError.message("Upload failed.") }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(ticket.contentType, forHTTPHeaderField: "Content-Type")
        let response: URLResponse
        if let fileURL {
            (_, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL)
        } else {
            (_, response) = try await URLSession.shared.upload(for: request, from: data ?? Data())
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GlimpseError.message("Upload failed. Check your connection and try again.")
        }
        return ticket.path
    }

    func reorderVideos(_ ids: [UUID]) async throws {
        for (index, id) in ids.enumerated() {
            try await client.from("profile_videos")
                .update(["position": index])
                .eq("id", value: id.uuidString)
                .execute()
        }
    }

    func accountState() async throws -> AccountState {
        try await client.rpc("account_state").execute().value
    }

    func setPause(days: Int) async throws -> Date? {
        let response = try await client.rpc("set_pause", params: ["p_days": days]).execute()
        let text = String(decoding: response.data, as: UTF8.self)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\" \n"))
        return text == "null" || text.isEmpty ? nil : FlexibleDate.parse(text)
    }

    func densityStatus() async throws -> DensityStatus {
        try await client.rpc("density_status").execute().value
    }

    func updateLocation(latitude: Double, longitude: Double) async throws {
        try await client.rpc("update_location", params: ["p_latitude": latitude, "p_longitude": longitude]).execute()
    }

    func deleteAccount() async throws {
        try await client.functions.invoke("delete-account")
        try? await client.auth.signOut(scope: .local)
    }

    func reportEmbedUnplayable(_ videoID: UUID) async {
        _ = try? await client.rpc("report_embed_unplayable", params: ["p_video": videoID.uuidString]).execute()
    }

    func deleteVideo(_ video: ProfileVideo) async throws {
        do {
            try await client.from("profile_videos").delete().eq("id", value: video.id.uuidString).execute()
        } catch let error as PostgrestError where error.message == "last_hosted" {
            throw GlimpseError.lastHostedClip
        }
        let paths = [video.storagePath, video.thumbnailPath].compactMap { $0 }
        guard !paths.isEmpty else { return }
        _ = try? await client.functions.invoke(
            "media",
            options: FunctionInvokeOptions(body: MediaPathsRequest(action: "delete", paths: paths))
        )
    }

    func addEmbed(_ link: EmbedLink, promptKey: String?) async throws -> ProfileVideo {
        do {
            return try await client.rpc(
                "add_embed_video",
                params: EmbedParams(url: link.canonicalURL.absoluteString, promptKey: promptKey)
            ).execute().value
        } catch let error as PostgrestError {
            switch error.message {
            case "invalid_embed_url": throw GlimpseError.invalidEmbedLink
            case "already_added": throw GlimpseError.videoAlreadyAdded
            case "story_link": throw GlimpseError.storyLink
            case "hosted_first": throw GlimpseError.hostedFirst
            case "too_old": throw GlimpseError.clipTooOld
            default: throw error
            }
        }
    }

    // MARK: Discovery

    func fetchFeed(limit: Int) async throws -> [FeedProfile] {
        try await client.rpc("get_feed", params: ["p_limit": limit]).execute().value
    }

    func logFeedEvents(_ events: [FeedEvent]) async {
        guard !events.isEmpty else { return }
        _ = try? await client.rpc("log_feed_events", params: FeedEventsParams(events: events)).execute()
    }

    func swipe(on userID: UUID, liked: Bool) async throws -> SwipeResult {
        try await mapLimits {
            try await client.rpc("swipe", params: SwipeParams(target: userID, liked: liked)).execute().value
        }
    }

    func likeQuota() async throws -> LikeQuota {
        try await client.rpc("like_quota").execute().value
    }

    func likesReceived() async throws -> LikesReceived {
        try await client.rpc("get_likes_received").execute().value
    }

    func verifyPurchase(signedTransaction: String) async throws -> Bool {
        let response: PurchaseResponse = try await client.functions.invoke(
            "verify-purchase",
            options: FunctionInvokeOptions(body: ["signed_transaction": signedTransaction])
        )
        return MembershipTier(plan: response.plan) != nil
    }

    func goldStatus() async throws -> GoldStatus {
        try await client.rpc("gold_status").execute().value
    }

    func startSpotlight() async throws -> Date {
        try await mapLimits { () async throws -> Date in
            try await client.rpc("start_spotlight").execute().value
        }
    }

    func rewindLastPass() async throws -> FeedProfile? {
        try await mapLimits {
            let response = try await client.rpc("rewind_last_pass").execute()
            let text = String(decoding: response.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text != "null" else { return nil }
            return try JSONDecoder.glimpse().decode(FeedProfile.self, from: response.data)
        }
    }

    func setTravel(latitude: Double, longitude: Double, city: String, days: Int) async throws -> Date {
        try await mapLimits { () async throws -> Date in
            try await client.rpc(
                "set_travel",
                params: TravelParams(latitude: latitude, longitude: longitude, city: city, days: days)
            ).execute().value
        }
    }

    func endTravel() async throws {
        try await client.rpc("end_travel").execute()
    }

    func clipInsights() async throws -> [ClipInsight] {
        try await mapLimits { () async throws -> [ClipInsight] in
            try await client.rpc("my_clip_insights").execute().value
        }
    }

    /// Turns the database's custom limit codes into typed errors.
    private func mapLimits<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as PostgrestError {
            switch (error.code, error.message) {
            case ("GL402", "daily_view_limit"): throw GlimpseError.outOfViews
            case ("GL402", "freeze_limit"): throw GlimpseError.freezeLimit
            case ("GL402", "pin_limit"): throw GlimpseError.pinLimit
            case ("GL402", "gold_required"): throw GlimpseError.goldRequired
            case ("GL402", "idea_limit"): throw GlimpseError.ideaLimit
            case ("GL402", "date_paused"): throw GlimpseError.datePaused
            case ("GL402", "date_exists"): throw GlimpseError.dateExists
            case ("GL402", "spotlight_used"): throw GlimpseError.spotlightUsed
            case ("GL402", "rewind_limit"): throw GlimpseError.rewindLimit
            case ("GL402", "city_not_open"): throw GlimpseError.cityNotOpen
            case ("GL402", "plus_required"): throw GlimpseError.plusRequired
            case ("GL402", "second_chance_limit"): throw GlimpseError.secondChanceLimit
            case ("GL402", _): throw GlimpseError.outOfLikes
            case ("GL423", _): throw GlimpseError.paused
            case ("GL429", _): throw GlimpseError.rateLimited
            default: throw error
            }
        }
    }

    func capacityStatus() async throws -> CapacityStatus {
        try await client.rpc("capacity_status").execute().value
    }

    // MARK: Connections

    func setFrozen(_ matchID: UUID, frozen: Bool) async throws {
        try await mapLimits {
            try await client.rpc("set_frozen", params: FreezeParams(match: matchID, frozen: frozen)).execute()
        }
    }

    func setPinned(_ matchID: UUID, pinned: Bool) async throws {
        try await mapLimits {
            try await client.rpc("set_pinned", params: PinParams(match: matchID, pinned: pinned)).execute()
        }
    }

    func pinnedMatchIDs() async throws -> Set<UUID> {
        let ids: [UUID] = try await client.rpc("my_pinned_matches").execute().value
        return Set(ids)
    }

    func submitExitFeedback(matchID: UUID, reason: ExitReason) async throws {
        try await client.rpc(
            "submit_exit_feedback",
            params: ["p_match": matchID.uuidString, "p_reason": reason.rawValue]
        ).execute()
    }

    func missedConnections() async throws -> [MissedConnection] {
        try await client.rpc("get_missed_connections").execute().value
    }

    func requestSecondChance(matchID: UUID) async throws {
        try await mapLimits {
            try await client.rpc("request_second_chance", params: ["p_match": matchID]).execute()
        }
    }

    func secondChances() async throws -> [SecondChance] {
        try await client.rpc("get_second_chances").execute().value
    }

    func respondToSecondChance(_ id: UUID, accept: Bool) async throws -> SwipeResult {
        try await client.rpc("respond_second_chance", params: SecondChanceResponse(id: id, accept: accept)).execute().value
    }

    func fetchMatches() async throws -> [MatchSummary] {
        try await client.rpc("get_matches").execute().value
    }

    func unmatch(_ matchID: UUID) async throws {
        try await client.rpc("unmatch", params: ["p_match": matchID]).execute()
    }

    func block(userID: UUID) async throws {
        try await client.rpc("block_user", params: ["p_target": userID]).execute()
    }

    func report(userID: UUID, reason: ReportReason, details: String?, matchID: UUID?) async throws {
        let params = ReportParams(target: userID, reason: reason, details: details, match: matchID)
        try await client.rpc("report_user", params: params).execute()
    }

    // MARK: Chat

    func fetchMessages(matchID: UUID) async throws -> [ChatMessage] {
        let latest: [ChatMessage] = try await client.from("messages")
            .select()
            .eq("match_id", value: matchID.uuidString)
            .order("created_at", ascending: false)
            .limit(300)
            .execute()
            .value
        return latest.reversed()
    }

    func send(_ body: String, matchID: UUID, replyTo: UUID?) async throws -> ChatMessage {
        let row = NewMessageRow(matchID: matchID, senderID: try currentUserID(), body: body, replyTo: replyTo)
        return try await mapLimits {
            try await client.from("messages").insert(row).select().single().execute().value
        }
    }

    func fetchReactions(matchID: UUID) async throws -> [MessageReaction] {
        try await client.from("message_reactions")
            .select()
            .eq("match_id", value: matchID.uuidString)
            .execute()
            .value
    }

    func react(to messageID: UUID, emoji: String?) async throws {
        try await client.rpc("react_to_message", params: ReactParams(message: messageID, emoji: emoji)).execute()
    }

    func deleteMessage(_ messageID: UUID) async throws {
        try await client.rpc("delete_message", params: ["p_message": messageID.uuidString]).execute()
    }

    func sendMedia(_ kind: MessageKind, fileURL: URL, duration: Double, matchID: UUID, replyTo: UUID?) async throws -> ChatMessage {
        let bytes = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? nil
        let path = try await upload(
            fileURL: fileURL, kind: "chat", ext: kind == .voice ? "m4a" : "mp4", bytes: bytes, limit: 15 * 1024 * 1024
        )
        let row = NewMediaMessageRow(
            matchID: matchID, senderID: try currentUserID(), kind: kind.rawValue, mediaPath: path,
            mediaDuration: (min(duration, kind.maxDuration) * 10).rounded() / 10, replyTo: replyTo
        )
        return try await mapLimits {
            try await client.from("messages").insert(row).select().single().execute().value
        }
    }

    func chatMediaURLs(for paths: [String]) async -> [String: URL] {
        let unique = Array(Set(paths))
        var resolved = await signedURLs.lookup(unique)
        let missing = unique.filter { resolved[$0] == nil }
        guard !missing.isEmpty else { return resolved }
        guard let response: MediaURLsResponse = try? await client.functions.invoke(
            "media",
            options: FunctionInvokeOptions(body: ChatMediaRequest(paths: missing))
        ) else { return resolved }
        var fresh: [String: URL] = [:]
        for (path, string) in response.urls {
            if let url = URL(string: string) { fresh[path] = url }
        }
        await signedURLs.store(fresh, validFor: 3000)
        resolved.merge(fresh) { current, _ in current }
        return resolved
    }

    func setPushScope(_ scope: PushScope) async throws {
        try await client.from("profiles")
            .update(["push_scope": scope.rawValue])
            .eq("id", value: currentUserKey())
            .execute()
    }

    func setLocale(_ code: String) async {
        _ = try? await client.from("profiles")
            .update(["locale": code])
            .eq("id", value: currentUserKey())
            .execute()
    }

    func recordConsents(_ kinds: [String], version: String, locale: String) async throws {
        try await client.rpc(
            "record_consents",
            params: ConsentParams(kinds: kinds, version: version, locale: locale)
        ).execute()
    }

    func myConsentVersion() async throws -> String? {
        let response = try await client.rpc("my_consent_version").execute()
        let text = String(decoding: response.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != "null" else { return nil }
        return try JSONDecoder().decode(String.self, from: response.data)
    }

    func setPushExtras(_ extras: [AlertExtra]) async throws {
        try await client.from("profiles")
            .update(["push_extras": extras.map(\.rawValue)])
            .eq("id", value: currentUserKey())
            .execute()
    }

    func setDataConsent(aiTraining: Bool, sharing: Bool) async throws {
        try await client.from("profiles")
            .update(["consent_ai_training": aiTraining, "consent_data_sharing": sharing])
            .eq("id", value: currentUserKey())
            .execute()
    }

    func markRead(matchID: UUID) async throws {
        try await client.rpc("mark_read", params: ["p_match": matchID]).execute()
    }

    func openChannel(matchID: UUID) async -> ChatChannel {
        let me = client.auth.currentUser?.id.uuidString.lowercased()
        let channel = client.channel("match:\(matchID.uuidString.lowercased())") { config in
            config.isPrivate = true
        }
        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: .eq("match_id", value: matchID)
        )
        let edits = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "messages",
            filter: .eq("match_id", value: matchID)
        )
        let reactionInserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "message_reactions",
            filter: .eq("match_id", value: matchID)
        )
        let reactionUpdates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "message_reactions",
            filter: .eq("match_id", value: matchID)
        )
        let typingEvents = channel.broadcastStream(event: "typing")

        let updates = AsyncStream<ChatMessage> { continuation in
            let task = Task {
                let decoder = JSONDecoder.glimpse()
                for await action in edits {
                    if let message = try? action.decodeRecord(as: ChatMessage.self, decoder: decoder) {
                        continuation.yield(message)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }

        let reactions = AsyncStream<MessageReaction> { continuation in
            let inserted = Task {
                let decoder = JSONDecoder.glimpse()
                for await action in reactionInserts {
                    if let reaction = try? action.decodeRecord(as: MessageReaction.self, decoder: decoder) {
                        continuation.yield(reaction)
                    }
                }
            }
            let updated = Task {
                let decoder = JSONDecoder.glimpse()
                for await action in reactionUpdates {
                    if let reaction = try? action.decodeRecord(as: MessageReaction.self, decoder: decoder) {
                        continuation.yield(reaction)
                    }
                }
            }
            continuation.onTermination = { _ in
                inserted.cancel()
                updated.cancel()
            }
        }

        let messages = AsyncStream<ChatMessage> { continuation in
            let task = Task {
                let decoder = JSONDecoder.glimpse()
                for await action in inserts {
                    if let message = try? action.decodeRecord(as: ChatMessage.self, decoder: decoder) {
                        continuation.yield(message)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }

        let typing = AsyncStream<Void> { continuation in
            let task = Task {
                for await event in typingEvents {
                    let sender = event["payload"]?.objectValue?["user_id"]?.stringValue
                        ?? event["user_id"]?.stringValue
                    if sender != me {
                        continuation.yield()
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }

        try? await channel.subscribeWithError()

        return ChatChannel(
            messages: messages,
            updates: updates,
            reactions: reactions,
            typing: typing,
            sendTyping: {
                try? await channel.broadcast(event: "typing", message: TypingPayload(userID: me ?? ""))
            },
            close: { [client] in
                await client.removeChannel(channel)
            }
        )
    }

    // MARK: 3-Minute Vibe Check

    func uploadVibeSegment(
        matchID: UUID, fileURL: URL, startedAt: Date, part: Int, duration: Double?, received: Bool
    ) async throws {
        let bytes = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? nil
        let path = try await upload(fileURL: fileURL, kind: "vibe", ext: "mp4", bytes: bytes, limit: 40 * 1024 * 1024)
        try await client.rpc(
            "vibe_register_segment",
            params: VibeSegmentParams(
                match: matchID, path: path, startedAt: startedAt, part: part, duration: duration, received: received
            )
        ).execute()
    }

    func vibeBackupDecision(matchID: UUID) async throws -> VibeBackupDecision {
        try await client.rpc("vibe_backup_decision", params: ["p_match": matchID]).execute().value
    }

    func vibeTopics(matchID: UUID) async throws -> [String] {
        try await client.rpc("vibe_topics", params: ["p_match": matchID]).execute().value
    }

    // MARK: Date ideas

    func dateIdea(matchID: UUID) async throws -> DateIdea? {
        let data = try await client.rpc("get_date_idea", params: ["p_match": matchID]).execute().data
        return try decodeOptional(DateIdea.self, data)
    }

    func nextDateIdea(matchID: UUID) async throws -> DateIdea? {
        try await mapLimits { () async throws -> DateIdea? in
            let data = try await client.rpc("next_date_idea", params: ["p_match": matchID]).execute().data
            return try decodeOptional(DateIdea.self, data)
        }
    }

    func logDateIdea(_ ideaID: UUID, feedback: DateIdea.Feedback) async {
        _ = try? await client.rpc("log_date_idea", params: ["p_suggestion": ideaID.uuidString, "p_kind": feedback.rawValue]).execute()
    }

    // MARK: Planned dates

    func plannedDate(matchID: UUID) async throws -> PlannedDate? {
        let data = try await client.rpc("get_planned_date", params: ["p_match": matchID]).execute().data
        return try decodeOptional(PlannedDate.self, data)
    }

    func proposeDate(matchID: UUID, ideaID: UUID, at date: Date) async throws -> PlannedDate {
        try await mapLimits { () async throws -> PlannedDate in
            try await client.rpc("propose_date", params: ProposeDateParams(match: matchID, suggestion: ideaID, at: date)).execute().value
        }
    }

    func respondDate(_ dateID: UUID, accept: Bool) async throws -> PlannedDate {
        try await mapLimits { () async throws -> PlannedDate in
            try await client.rpc("respond_date", params: RespondDateParams(date: dateID, accept: accept)).execute().value
        }
    }

    func cancelDate(_ dateID: UUID) async throws {
        try await client.rpc("cancel_date", params: ["p_date": dateID]).execute()
    }

    func myPlannedDates() async throws -> [UpcomingDate] {
        try await client.rpc("my_planned_dates").execute().value
    }

    func checkInDate(_ dateID: UUID, outcome: DateOutcome) async throws {
        try await client.rpc("date_checkin", params: ["p_date": dateID.uuidString, "p_outcome": outcome.rawValue]).execute()
    }

    /// An RPC answering a JSON object or `null`.
    private func decodeOptional<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T? {
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != "null" else { return nil }
        return try JSONDecoder.glimpse().decode(T.self, from: data)
    }

    func logVibeCapture(matchID: UUID, kind: String) async {
        _ = try? await client.rpc("vibe_log_capture", params: ["p_match": matchID.uuidString, "p_kind": kind]).execute()
    }

    func vibeCheck(matchID: UUID) async throws -> VibeCheckState {
        try await client.rpc("get_vibe_check", params: ["p_match": matchID]).execute().value
    }

    func vibeGreenLight(matchID: UUID) async throws {
        try await client.rpc("vibe_green_light", params: ["p_match": matchID]).execute()
    }

    func vibePropose(matchID: UUID, at date: Date) async throws {
        try await client.rpc("vibe_propose", params: VibeProposal(match: matchID, at: date)).execute()
    }

    func vibeRespond(matchID: UUID, accept: Bool) async throws {
        try await client.rpc("vibe_respond", params: VibeAnswer(match: matchID, accept: accept)).execute()
    }

    func vibeDismissNudge(matchID: UUID) async throws {
        try await client.rpc("vibe_dismiss_nudge", params: ["p_match": matchID]).execute()
    }

    func vibeMarkStarted(matchID: UUID) async throws -> VibeClock {
        try await client.rpc("vibe_mark_started", params: ["p_match": matchID]).execute().value
    }

    func vibeSubmitResult(matchID: UUID, outcome: VibeOutcome) async throws -> Bool {
        let response: VibeResultResponse = try await client.rpc(
            "vibe_submit_result",
            params: ["p_match": matchID.uuidString, "p_outcome": outcome.rawValue]
        ).execute().value
        return response.vibeVerified
    }

    func vibeIceServers(matchID: UUID) async throws -> [IceServerConfig] {
        let response: IceServersResponse = try await client.functions.invoke(
            "vibe-ice",
            options: FunctionInvokeOptions(body: ["match_id": matchID.uuidString])
        )
        return response.iceServers
    }

    func openVibeSignaling(matchID: UUID) async -> VibeSignalChannel {
        let me = client.auth.currentUser?.id.uuidString.lowercased() ?? ""
        let channel = client.channel("match:\(matchID.uuidString.lowercased()):vibe") { config in
            config.isPrivate = true
        }
        let raw = channel.broadcastStream(event: "signal")
        let signals = AsyncStream<VibeSignal> { continuation in
            let task = Task {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                for await event in raw {
                    let payload = event["payload"]?.objectValue ?? event
                    guard let data = try? encoder.encode(payload),
                          let signal = try? decoder.decode(VibeSignal.self, from: data),
                          signal.sender != me
                    else { continue }
                    continuation.yield(signal)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        try? await channel.subscribeWithError()
        return VibeSignalChannel(
            signals: signals,
            send: { signal in
                var stamped = signal
                stamped.sender = me
                try? await channel.broadcast(event: "signal", message: stamped)
            },
            close: { [client] in
                await client.removeChannel(channel)
            }
        )
    }

    // MARK: Notifications

    func notifications() async throws -> [AppNotification] {
        try await client.from("notifications")
            .select()
            .neq("kind", value: AppNotification.Kind.newMessage.rawValue)
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
            .value
    }

    func markNotificationsRead(_ ids: [UUID]?) async throws {
        try await client.rpc("mark_notifications_read", params: MarkReadParams(ids: ids)).execute()
    }

    func registerPushToken(_ token: String, environment: String) async throws {
        try await client.rpc("register_push_token", params: ["p_token": token, "p_environment": environment]).execute()
    }

    func unregisterPushToken(_ token: String) async {
        _ = try? await client.rpc("unregister_push_token", params: ["p_token": token]).execute()
    }

    // MARK: Verification

    func startVerification() async throws -> VerificationChallenge {
        try await mapLimits {
            try await client.rpc("start_verification").execute().value
        }
    }

    func submitVerification(_ challenge: VerificationChallenge, clip: RecordedClip) async throws {
        let path = try await upload(fileURL: clip.fileURL, kind: "verification", ext: "mp4")
        try await client.rpc(
            "submit_verification",
            params: ["p_request": challenge.id.uuidString, "p_storage_path": path]
        ).execute()
    }

    // MARK: Telemetry

    func track(_ event: String, properties: [String: String]) async {
        _ = try? await client.rpc("track_event", params: TrackParams(name: event, props: properties)).execute()
    }

    func reportDiagnostic(kind: String, payload: Data, appVersion: String?) async {
        guard let json = try? JSONDecoder().decode(AnyJSON.self, from: payload) else { return }
        _ = try? await client.rpc(
            "report_diagnostic",
            params: DiagnosticParams(kind: kind, payload: json, appVersion: appVersion)
        ).execute()
    }

    // MARK: Media

    func mediaURLs(for paths: [String]) async -> [String: URL] {
        let unique = Array(Set(paths))
        var resolved = await signedURLs.lookup(unique)
        let missing = unique.filter { resolved[$0] == nil }
        guard !missing.isEmpty else { return resolved }

        guard let response: MediaURLsResponse = try? await client.functions.invoke(
            "media",
            options: FunctionInvokeOptions(body: MediaPathsRequest(action: "view_urls", paths: missing))
        ) else { return resolved }

        var fresh: [String: URL] = [:]
        for (path, string) in response.urls {
            if let url = URL(string: string) { fresh[path] = url }
        }
        await signedURLs.store(fresh, validFor: 3000)
        resolved.merge(fresh) { current, _ in current }
        return resolved
    }
}

// MARK: - Request payloads

private struct NewProfileRow: Encodable, Sendable {
    let id: String
    let displayName: String
    let birthdate: String
    let gender: Gender
    let interestedIn: [Gender]
    let bio: String?
    let city: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case birthdate
        case gender
        case interestedIn = "interested_in"
        case bio
        case city
    }
}

private struct NewVideoRow: Encodable, Sendable {
    let userID: String
    let source: VideoSource
    let storagePath: String
    let thumbnailPath: String?
    let durationSeconds: Double
    let promptKey: String?
    /// When the clip was filmed (camera-roll metadata); the server checks it's within a year.
    let capturedAt: Date?

    enum CodingKeys: String, CodingKey {
        case capturedAt = "captured_at"
        case userID = "user_id"
        case source
        case storagePath = "storage_path"
        case thumbnailPath = "thumbnail_path"
        case durationSeconds = "duration_seconds"
        case promptKey = "prompt_key"
    }
}

/// Always sends every key, so clearing a prompt or tag writes `null`.
private struct VideoDetailsRow: Encodable, Sendable {
    let promptKey: String?
    let meMarkerX: Double?
    let meMarkerY: Double?

    enum CodingKeys: String, CodingKey {
        case promptKey = "prompt_key"
        case meMarkerX = "me_marker_x"
        case meMarkerY = "me_marker_y"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(promptKey, forKey: .promptKey)
        try container.encode(meMarkerX, forKey: .meMarkerX)
        try container.encode(meMarkerY, forKey: .meMarkerY)
    }
}

private struct UploadTicket: Decodable, Sendable {
    let path: String
    let uploadURL: String
    let contentType: String

    enum CodingKeys: String, CodingKey {
        case path
        case uploadURL = "upload_url"
        case contentType = "content_type"
    }
}

private struct MediaPathsRequest: Encodable, Sendable {
    let action: String
    let paths: [String]
}

private struct MediaURLsResponse: Decodable, Sendable {
    let urls: [String: String]
}

private struct PinParams: Encodable, Sendable {
    let match: UUID
    let pinned: Bool

    enum CodingKeys: String, CodingKey {
        case match = "p_match"
        case pinned = "p_pinned"
    }
}

private struct FreezeParams: Encodable, Sendable {
    let match: UUID
    let frozen: Bool

    enum CodingKeys: String, CodingKey {
        case match = "p_match"
        case frozen = "p_frozen"
    }
}

private struct SecondChanceResponse: Encodable, Sendable {
    let id: UUID
    let accept: Bool

    enum CodingKeys: String, CodingKey {
        case id = "p_id"
        case accept = "p_accept"
    }
}

private struct NewMessageRow: Encodable, Sendable {
    let matchID: UUID
    let senderID: UUID
    let body: String
    let replyTo: UUID?

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case senderID = "sender_id"
        case body
        case replyTo = "reply_to"
    }
}

private struct SwipeParams: Encodable, Sendable {
    let target: UUID
    let liked: Bool

    enum CodingKeys: String, CodingKey {
        case target = "p_target"
        case liked = "p_liked"
    }
}

private struct ReportParams: Encodable, Sendable {
    let target: UUID
    let reason: ReportReason
    let details: String?
    let match: UUID?

    enum CodingKeys: String, CodingKey {
        case target = "p_target"
        case reason = "p_reason"
        case details = "p_details"
        case match = "p_match"
    }
}

private struct MarkReadParams: Encodable, Sendable {
    let ids: [UUID]?

    enum CodingKeys: String, CodingKey {
        case ids = "p_ids"
    }

    // Always send the key so `null` means "mark everything read".
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ids, forKey: .ids)
    }
}

private struct TrackParams: Encodable, Sendable {
    let name: String
    let props: [String: String]

    enum CodingKeys: String, CodingKey {
        case name = "p_name"
        case props = "p_props"
    }
}

private struct DiagnosticParams: Encodable, Sendable {
    let kind: String
    let payload: AnyJSON
    let appVersion: String?

    enum CodingKeys: String, CodingKey {
        case kind = "p_kind"
        case payload = "p_payload"
        case appVersion = "p_app_version"
    }
}

private struct VibeProposal: Encodable, Sendable {
    let match: UUID
    let at: Date

    enum CodingKeys: String, CodingKey {
        case match = "p_match"
        case at = "p_at"
    }
}

private struct VibeAnswer: Encodable, Sendable {
    let match: UUID
    let accept: Bool

    enum CodingKeys: String, CodingKey {
        case match = "p_match"
        case accept = "p_accept"
    }
}

private struct VibeResultResponse: Decodable, Sendable {
    let vibeVerified: Bool

    enum CodingKeys: String, CodingKey {
        case vibeVerified = "vibe_verified"
    }
}

private struct IceServersResponse: Decodable, Sendable {
    let iceServers: [IceServerConfig]

    enum CodingKeys: String, CodingKey {
        case iceServers = "ice_servers"
    }
}

private struct ProposeDateParams: Encodable, Sendable {
    let match: UUID
    let suggestion: UUID
    let at: Date

    enum CodingKeys: String, CodingKey {
        case match = "p_match"
        case suggestion = "p_suggestion"
        case at = "p_at"
    }
}

private struct RespondDateParams: Encodable, Sendable {
    let date: UUID
    let accept: Bool

    enum CodingKeys: String, CodingKey {
        case date = "p_date"
        case accept = "p_accept"
    }
}

private struct HeightParams: Encodable, Sendable {
    let heightCm: Int?
    let show: Bool

    enum CodingKeys: String, CodingKey {
        case heightCm = "p_height_cm"
        case show = "p_show"
    }

    // Both arguments are always sent (a missing one wouldn't match the function).
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(heightCm, forKey: .heightCm)
        try container.encode(show, forKey: .show)
    }
}

private struct ConsentParams: Encodable, Sendable {
    let kinds: [String]
    let version: String
    let locale: String

    enum CodingKeys: String, CodingKey {
        case kinds = "p_kinds"
        case version = "p_version"
        case locale = "p_locale"
    }
}

private struct TravelParams: Encodable, Sendable {
    let latitude: Double
    let longitude: Double
    let city: String
    let days: Int

    enum CodingKeys: String, CodingKey {
        case latitude = "p_latitude"
        case longitude = "p_longitude"
        case city = "p_city"
        case days = "p_days"
    }
}

private struct PurchaseResponse: Decodable, Sendable {
    let plan: String
}

private struct FeedEventsParams: Encodable, Sendable {
    let events: [FeedEvent]

    enum CodingKeys: String, CodingKey {
        case events = "p_events"
    }
}

private struct VibeSegmentParams: Encodable, Sendable {
    let match: UUID
    let path: String
    let startedAt: Date
    let part: Int
    let duration: Double?
    let received: Bool

    enum CodingKeys: String, CodingKey {
        case match = "p_match"
        case path = "p_path"
        case startedAt = "p_started_at"
        case part = "p_part"
        case duration = "p_duration"
        case received = "p_received"
    }
}

private struct NewMediaMessageRow: Encodable, Sendable {
    let matchID: UUID
    let senderID: UUID
    /// Replaced by the server ("🎤 Voice message" / "🎥 Video message").
    let body = "media"
    let kind: String
    let mediaPath: String
    let mediaDuration: Double
    let replyTo: UUID?

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case senderID = "sender_id"
        case body
        case kind
        case mediaPath = "media_path"
        case mediaDuration = "media_duration"
        case replyTo = "reply_to"
    }
}

private struct ChatMediaRequest: Encodable, Sendable {
    let action = "view_urls"
    let kind = "chat"
    let paths: [String]
}

/// Sends `p_emoji: null` explicitly to remove a reaction.
private struct ReactParams: Encodable, Sendable {
    let message: UUID
    let emoji: String?

    enum CodingKeys: String, CodingKey {
        case message = "p_message"
        case emoji = "p_emoji"
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(message, forKey: .message)
        try container.encode(emoji, forKey: .emoji)
    }
}

private struct UploadTicketRequest: Encodable, Sendable {
    let action = "upload_url"
    let kind: String
    let ext: String
    let bytes: Int?
}

private struct EmbedParams: Encodable, Sendable {
    let url: String
    let promptKey: String?

    enum CodingKeys: String, CodingKey {
        case url = "p_url"
        case promptKey = "p_prompt_key"
    }
}

private struct TypingPayload: Codable, Sendable {
    let userID: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
    }
}

/// Signed storage URLs are reused until shortly before they expire.
private actor SignedURLCache {
    private var entries: [String: (url: URL, expires: Date)] = [:]

    func lookup(_ paths: [String]) -> [String: URL] {
        let now = Date.now
        var result: [String: URL] = [:]
        for path in paths {
            if let entry = entries[path], entry.expires > now {
                result[path] = entry.url
            }
        }
        return result
    }

    func store(_ urls: [String: URL], validFor seconds: TimeInterval) {
        let expires = Date.now.addingTimeInterval(seconds)
        for (path, url) in urls {
            entries[path] = (url, expires)
        }
    }
}
