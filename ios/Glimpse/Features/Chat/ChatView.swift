import SwiftUI

struct ChatView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var model: ChatModel
    @State private var showReport = false
    @State private var confirmUnmatch = false
    @State private var showExitSurvey = false
    @State private var showPropose = false
    @State private var showCall = false
    @State private var showVibeInfo = false
    @State private var friendlyFollowUp = false
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
                        MessageBubble(
                            message: message,
                            isMine: message.senderID == myID,
                            showsTail: isLastInRun(index)
                        )
                        .id(message.id)
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
                        }
                    },
                    onJoin: { showCall = true }
                )
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .navigationBarTitleDisplayMode(.inline)
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
                    Button(model.isFrozen ? "Unfreeze" : "Freeze connection", systemImage: "snowflake") {
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
        .task { await model.run(using: app.backend, myID: myID) }
        .sheet(isPresented: $showReport) {
            ReportSheet(name: model.match.displayName) { reason, details in
                try await app.backend.report(
                    userID: model.match.otherUserID, reason: reason, details: details, matchID: model.match.matchID
                )
                leave()
            }
        }
        .confirmationDialog("Unmatch \(model.match.displayName)?", isPresented: $confirmUnmatch, titleVisibility: .visible) {
            Button("Unmatch", role: .destructive) {
                Task {
                    try? await app.backend.unmatch(model.match.matchID)
                    showExitSurvey = true
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
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message \(model.match.displayName)", text: $model.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Palette.surfaceRaised, in: .rect(cornerRadius: 22))
                    .onChange(of: model.draft) { model.draftChanged() }
                    .disabled(model.hasEnded)

                Button("Send", systemImage: "arrow.up") {
                    Task {
                        await model.send(using: app.backend)
                        app.track("message_sent")
                    }
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.onMint)
                .frame(width: 44, height: 44)
                .background(model.canSend ? Palette.mint : Palette.surfaceRaised, in: .circle)
                .disabled(!model.canSend)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Palette.midnight.opacity(0.96))
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
            return "The Vibe Check isn't available in this conversation."
        }
        if vibe.iHoldKey {
            return "When the conversation is flowing, you can invite \(model.match.displayName) to a 3-minute video chat, or give the green light for them to suggest a time. It ends on its own after 3 minutes."
        }
        return "Vibe Checks unlock when the conversation flows naturally."
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
                Text("Say something real. Quiet connections are the first to go when either of you hits 20.")
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
