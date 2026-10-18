import SwiftUI

struct ChatView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Date ideas someone closed (by id), so the card stays away.
    @AppStorage("dateIdeas.dismissed") private var dismissedDateIdeas = ""
    @State private var model: ChatModel
    @State private var showReport = false
    @State private var confirmUnmatch = false
    @State private var showExitSurvey = false
    @State private var showPropose = false
    @State private var showCall = false
    @State private var showDatePlan = false
    @State private var showVibeInfo = false
    @State private var friendlyFollowUp = false
    @State private var recorder = ChatMediaRecorder()
    @FocusState private var composerFocused: Bool

    let onConnectionChanged: () -> Void

    init(match: MatchSummary, onConnectionChanged: @escaping () -> Void = {}) {
        _model = State(initialValue: ChatModel(match: match))
        self.onConnectionChanged = onConnectionChanged
    }

    private var myID: UUID? { app.profile?.id }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ConversationIntro(name: model.match.displayName, isEmpty: model.messages.isEmpty && !model.isLoading)
                        .padding(.bottom, 12)

                    ForEach(Array(model.messages.enumerated()), id: \.element.id) { index, message in
                        if let stamp = timeStamp(before: index) {
                            Text(stamp)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Palette.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        MessageBubble(
                            message: message,
                            isMine: message.senderID == myID,
                            showsTail: isLastInRun(index),
                            quoted: model.message(withID: message.replyTo),
                            quotedAuthor: author(of: model.message(withID: message.replyTo)),
                            reactions: model.reactions(on: message),
                            myID: myID,
                            canDelete: model.canDelete(message, myID: myID),
                            mediaURL: model.mediaURL(for: message),
                            onReact: { emoji in
                                Task { await model.react(to: message, with: emoji, myID: myID, using: app.backend) }
                            },
                            onReply: { startReply(to: message) },
                            onDelete: { Task { await model.delete(message, using: app.backend) } },
                            onTapQuote: {
                                if let quoted = message.replyTo {
                                    withAnimation(.snappy) { proxy.scrollTo(quoted, anchor: .center) }
                                }
                            }
                        )
                        .id(message.id)
                        if message.id == lastSeenID {
                            Text("Seen")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Palette.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .accessibilityIdentifier("chat.seen")
                        }
                    }

                    if model.isOtherTyping {
                        TypingIndicator()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("typing")
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .animation(.snappy(duration: 0.25), value: model.messages.count)
                .animation(.snappy(duration: 0.25), value: model.isOtherTyping)
                .animation(.snappy(duration: 0.25), value: model.reactions)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: model.isOtherTyping) { _, typing in
                if typing { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
        .background(Palette.midnight)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
            if let plan = model.plannedDate, !model.hasEnded {
                PlannedDateCard(
                    plan: plan,
                    name: model.match.displayName,
                    myID: myID,
                    onAccept: {
                        Task {
                            await model.respondToDate(accept: true, using: app.backend)
                            app.matchesDidChange()
                        }
                    },
                    onOtherTime: { showDatePlan = true },
                    onCancel: {
                        Task {
                            await model.cancelDate(using: app.backend)
                            app.matchesDidChange()
                        }
                    },
                    onDirections: { openURL($0) },
                    onCheckIn: { outcome in
                        Task { await model.checkIn(outcome, using: app.backend) }
                        app.track("date_checkin", ["outcome": outcome.rawValue])
                    }
                )
                .background(Palette.midnight)
            } else if let idea = model.dateIdea, !dismissedDateIdeas.contains(idea.id.uuidString) {
                DateIdeaCard(
                    idea: idea,
                    onDirections: { url in
                        Task { await app.backend.logDateIdea(idea.id, feedback: .openMaps) }
                        openURL(url)
                    },
                    onPickTime: { showDatePlan = true },
                    onAnother: {
                        Task { await model.anotherDateIdea(using: app.backend) }
                    },
                    onDismiss: {
                        Task { await app.backend.logDateIdea(idea.id, feedback: .notForUs) }
                        dismissedDateIdeas += idea.id.uuidString + ","
                    }
                )
                .background(Palette.midnight)
            }
            if let vibe = model.vibe, !model.hasEnded {
                VibeCheckBanner(
                    state: vibe,
                    name: model.match.displayName,
                    onInvite: { showPropose = true },
                    onGreenLight: {
                        Task {
                            await model.vibeAction(using: app.backend) {
                                try await app.backend.vibeGreenLight(matchID: model.match.matchID)
                            }
                            app.track("vibe_green_light")
                        }
                    },
                    onNotYet: {
                        Task {
                            await model.vibeAction(using: app.backend) {
                                try await app.backend.vibeDismissNudge(matchID: model.match.matchID)
                            }
                        }
                    },
                    onSuggest: { showPropose = true },
                    onAnswer: { accept in
                        Task {
                            await model.vibeAction(using: app.backend) {
                                try await app.backend.vibeRespond(matchID: model.match.matchID, accept: accept)
                            }
                            if accept { await app.offerAlerts(.vibeCheck, name: model.match.displayName) }
                        }
                    },
                    onJoin: { showCall = true }
                )
                // Opaque, so messages never show through behind the banner while scrolling.
                .padding(.bottom, 6)
                .background(Palette.midnight)
            }
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Palette.midnight, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    AvatarView(name: model.match.displayName, size: 30)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Text(model.match.displayName).font(.glimpseHeadline)
                            if model.vibe?.vibeVerified == true || model.match.vibeVerified == true {
                                VerifiedBadge(size: 14)
                                    .accessibilityLabel("Vibe Verified")
                            }
                        }
                        if let away = model.match.otherPausedUntil, away > .now {
                            Text("Away until \(away.formatted(.dateTime.month().day()))")
                                .font(.caption2)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button(model.isFrozen ? String(localized: "Unfreeze") : String(localized: "Freeze connection"), systemImage: "snowflake") {
                        Task {
                            do {
                                try await model.toggleFreeze(using: app.backend)
                                app.matchesDidChange()
                            } catch GlimpseError.freezeLimit {
                                app.paywall = .settings
                            } catch {
                                model.errorMessage = GlimpseError.describe(error)
                            }
                        }
                    }
                    Button("About the Vibe Check", systemImage: "video.bubble") { showVibeInfo = true }
                    Button("Unmatch", systemImage: "xmark.circle", role: .destructive) {
                        confirmUnmatch = true
                    }
                    Button("Report or block", systemImage: "flag") {
                        showReport = true
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .bottom) {
            if recorder.isRecording, recorder.kind == .video {
                VideoNotePreview(recorder: recorder)
                    .padding(.bottom, 120)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.snappy, value: recorder.isRecording)
        .onChange(of: recorder.reachedCap) { _, reached in
            guard reached else { return }
            Task { if let recording = await recorder.finish() { await sendRecording(recording) } }
        }
        .onDisappear { recorder.teardown() }
        .task { recorder.demoFallback = app.isDemo }
        .task { await model.run(using: app.backend, myID: myID) }
        .sheet(isPresented: $showReport) {
            ReportSheet(
                name: model.match.displayName,
                onSubmit: { reason, details in
                    try await app.backend.report(
                        userID: model.match.otherUserID, reason: reason, details: details, matchID: model.match.matchID
                    )
                },
                onDone: { leave() }
            )
        }
        .confirmationDialog("Unmatch \(model.match.displayName)?", isPresented: $confirmUnmatch, titleVisibility: .visible) {
            Button("Unmatch", role: .destructive) {
                Task {
                    try? await app.backend.unmatch(model.match.matchID)
                    // Only after a real conversation, and at most once a week.
                    if model.messages.count >= 3, SurveyPacing.mayAsk() {
                        SurveyPacing.recordAsked()
                        showExitSurvey = true
                    } else {
                        leave()
                    }
                }
            }
        } message: {
            Text("This frees a spot. You won't see each other again.")
        }
        .sheet(isPresented: $showExitSurvey) {
            ExitSurveySheet(name: model.match.displayName) { reason in
                if let reason {
                    Task { try? await app.backend.submitExitFeedback(matchID: model.match.matchID, reason: reason) }
                }
                leave()
            }
        }
        .sheet(isPresented: $showPropose) {
            VibeProposeSheet(name: model.match.displayName, allowNow: model.vibe?.iHoldKey == true) { date in
                Task {
                    await model.vibeAction(using: app.backend) {
                        try await app.backend.vibePropose(matchID: model.match.matchID, at: date)
                    }
                    app.track("vibe_proposed")
                    await app.offerAlerts(.vibeCheck, name: model.match.displayName)
                }
            }
        }
        .task { await model.refreshDateIdea(using: app.backend) }
        // While a suggested date waits for an answer, check back every few seconds.
        .task(id: model.plannedDate?.status) {
            while model.plannedDate?.status == .proposed, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                await model.refreshDateIdea(using: app.backend)
            }
        }
        .sheet(isPresented: $showDatePlan) {
            DatePlanSheet(
                place: model.dateIdea?.spot?.name ?? model.dateIdea?.idea ?? model.plannedDate?.place ?? "",
                name: model.match.displayName
            ) { when in
                Task {
                    if await model.proposeDate(at: when, using: app.backend) {
                        if let idea = model.dateIdea {
                            await app.backend.logDateIdea(idea.id, feedback: .shared)
                        }
                        app.track("date_proposed")
                        app.matchesDidChange()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCall) {
            if let myID {
                VibeCallView(match: model.match, myID: myID, backend: app.backend) { outcome in
                    handleVibeOutcome(outcome)
                }
            }
        }
        .alert("The 3-Minute Vibe Check", isPresented: $showVibeInfo) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text(vibeInfoText)
        }
        .confirmationDialog("Friendly, no spark", isPresented: $friendlyFollowUp, titleVisibility: .visible) {
            Button("Keep chatting") {}
            Button("Archive respectfully") {
                Task {
                    try? await app.backend.unmatch(model.match.matchID)
                    leave()
                }
            }
        } message: {
            Text("No hard feelings either way. This doesn't affect anyone's standing.")
        }
    }

    @ViewBuilder
    private var composer: some View {
        if model.hasEnded {
            Label("This connection has ended", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Palette.surface)
        } else {
            activeComposer
        }
    }

    private var activeComposer: some View {
        VStack(spacing: 6) {
            if let error = model.errorMessage {
                ErrorText(error).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let replying = model.replyingTo {
                HStack(spacing: 10) {
                    Capsule().fill(Palette.violet).frame(width: 3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Replying to \(author(of: replying))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.violet)
                        Text(replying.body)
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Button("Cancel reply", systemImage: "xmark.circle.fill") { model.replyingTo = nil }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Palette.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                // One compact line: the accent bar sizes to the text, not to the free space.
                .fixedSize(horizontal: false, vertical: true)
                .background(Palette.surface, in: .rect(cornerRadius: 14))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("chat.replyBar")
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let hint = recorder.errorMessage, !recorder.isRecording {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .task(id: hint) {
                        try? await Task.sleep(for: .seconds(3))
                        recorder.errorMessage = nil
                    }
            }
            HStack(alignment: .bottom, spacing: 8) {
                if recorder.isRecording {
                    ChatRecordingBar(recorder: recorder)
                } else {
                    TextField("Message \(model.match.displayName)", text: $model.draft, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($composerFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Palette.surfaceRaised, in: .rect(cornerRadius: 22))
                        .onChange(of: model.draft) { model.draftChanged() }
                        .disabled(model.hasEnded)
                }

                if recorder.phase == .locked || model.canSend {
                    Button("Send", systemImage: "arrow.up") {
                        Task {
                            if recorder.phase == .locked {
                                if let recording = await recorder.finish() { await sendRecording(recording) }
                            } else {
                                await model.send(using: app.backend)
                                app.track("message_sent")
                                await app.offerAlerts(.replies, name: model.match.displayName)
                            }
                        }
                    }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.onMint)
                    .frame(width: 44, height: 44)
                    .background(Palette.mint, in: .circle)
                    .accessibilityIdentifier("chat.send")
                } else {
                    // Hold to record (WhatsApp-style): selfie video note, or voice.
                    ChatRecordButton(kind: .video, recorder: recorder) { recording in
                        Task { await sendRecording(recording) }
                    }
                    ChatRecordButton(kind: .voice, recorder: recorder) { recording in
                        Task { await sendRecording(recording) }
                    }
                }
            }
            .disabled(model.isSendingMedia)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Palette.midnight.opacity(0.96))
    }

    private func sendRecording(_ recording: ChatMediaRecorder.Recording) async {
        await model.sendMedia(recording, using: app.backend)
        app.track(recording.kind == .voice ? "voice_message_sent" : "video_message_sent")
    }

    /// My most recent message the other person has read ("Seen" goes under it).
    private var lastSeenID: UUID? {
        guard let last = model.messages.last(where: { $0.senderID == myID }), last.readAt != nil else { return nil }
        return last.id
    }

    private func author(of message: ChatMessage?) -> String {
        guard let message else { return "" }
        return message.senderID == myID ? "You" : model.match.displayName
    }

    private func startReply(to message: ChatMessage) {
        guard !message.isUnsent, !model.hasEnded else { return }
        withAnimation(.snappy) { model.replyingTo = message }
        composerFocused = true
    }

    /// A time header at the start, and whenever an hour or more passed between messages.
    private func timeStamp(before index: Int) -> String? {
        let message = model.messages[index]
        if index > 0, message.createdAt.timeIntervalSince(model.messages[index - 1].createdAt) < 3600 {
            return nil
        }
        let date = message.createdAt
        if Calendar.current.isDateInToday(date) {
            return String(localized: "Today \(date.formatted(date: .omitted, time: .shortened))")
        }
        if Calendar.current.isDateInYesterday(date) {
            return String(localized: "Yesterday \(date.formatted(date: .omitted, time: .shortened))")
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute())
    }

    private func isLastInRun(_ index: Int) -> Bool {
        let messages = model.messages
        guard index + 1 < messages.count else { return true }
        return messages[index + 1].senderID != messages[index].senderID
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let last = model.messages.last else { return }
        withAnimation(.snappy) { proxy.scrollTo(last.id, anchor: .bottom) }
    }

    private var vibeInfoText: String {
        guard let vibe = model.vibe else { return "Vibe Checks unlock when the conversation flows naturally." }
        if vibe.status == .disabled {
            return String(localized: "The Vibe Check isn't available in this conversation.")
        }
        if vibe.iHoldKey {
            return String(localized: "When the conversation is flowing, you can invite \(model.match.displayName) to a 3-minute video chat, or give the green light for them to suggest a time. It ends on its own after 3 minutes.")
        }
        return String(localized: "Vibe Checks unlock when the conversation flows naturally.")
    }

    private func handleVibeOutcome(_ outcome: VibeOutcome?) {
        guard let outcome else {
            Task { await model.refreshVibe(using: app.backend) }
            return
        }
        app.track("vibe_check_completed", ["outcome": outcome.rawValue])
        Task {
            _ = try? await app.backend.vibeSubmitResult(matchID: model.match.matchID, outcome: outcome)
            await model.refreshVibe(using: app.backend)
            await model.refreshDateIdea(using: app.backend)
            app.matchesDidChange()
        }
        switch outcome {
        case .matched: break
        case .friendly: friendlyFollowUp = true
        case .report: showReport = true
        }
    }

    private func leave() {
        onConnectionChanged()
        app.matchesDidChange()
        dismiss()
    }
}

private struct ConversationIntro: View {
    let name: String
    let isEmpty: Bool

    var body: some View {
        VStack(spacing: 10) {
            AvatarView(name: name, size: 72, ringColor: Palette.mint)
            Text("You matched with \(name)")
                .font(.glimpseHeadline)
            if isEmpty {
                Text("Say something real. Quiet connections are the first to go when either of you hits 15.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }
}
