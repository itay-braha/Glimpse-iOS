import SwiftUI

struct MatchesView: View {
    @Environment(AppModel.self) private var app
    @State private var model = MatchesModel()
    @State private var pendingUnmatch: MatchSummary?
    @State private var exitSurveyFor: MatchSummary?
    @State private var reportTarget: MatchSummary?

    var body: some View {
        @Bindable var app = app

        NavigationStack(path: $app.connectionsPath) {
            List {
                Section {
                    CapacityHeader(active: model.matches.count, cap: MatchesModel.cap)
                    if model.likesTotal > 0 {
                        Button {
                            app.showLikesYou = true
                        } label: {
                            LikedYouCard(count: model.likesTotal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                if !model.secondChances.isEmpty {
                    Section("Second chances") {
                        ForEach(model.secondChances) { request in
                            SecondChanceRow(request: request) { accept in
                                Task {
                                    if let match = await model.respond(to: request, accept: accept, using: app.backend) {
                                        app.openChat(match)
                                    }
                                    app.matchesDidChange()
                                }
                            }
                        }
                    }
                    .listRowBackground(Palette.surface)
                }

                if !model.notices.isEmpty {
                    Section {
                        ForEach(model.notices) { notice in
                            NoticeRow(notice: notice) {
                                Task { await model.dismiss(notice, using: app.backend) }
                            }
                        }
                    }
                    .listRowBackground(Palette.surface)
                }

                if !model.pinnedMatches.isEmpty {
                    Section("Pinned") {
                        ForEach(model.pinnedMatches) { match in
                            conversationRow(match)
                        }
                    }
                    .listRowBackground(Palette.surface)
                }

                if !model.newMatches.isEmpty {
                    Section("New matches") {
                        ScrollView(.horizontal) {
                            HStack(spacing: 16) {
                                ForEach(model.newMatches) { match in
                                    NavigationLink(value: match) {
                                        NewMatchBubble(match: match, imageURL: model.avatarURL(for: match))
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu { actions(for: match) }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                        .scrollIndicators(.hidden)
                        .listRowInsets(EdgeInsets())
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Conversations") {
                    ForEach(model.conversations) { match in
                        conversationRow(match)
                    }
                    if model.conversations.isEmpty && model.hasLoaded {
                        Text("No conversations yet. Your matches are waiting for a hello.")
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .listRowBackground(Palette.surface)

                Section {
                    NavigationLink {
                        MissedConnectionsView()
                    } label: {
                        Label(
                            model.missedCount > 0 ? "Missed connections (\(model.missedCount))" : "Missed connections",
                            systemImage: "clock.arrow.circlepath"
                        )
                    }
                } footer: {
                    Text("Hold anyone for pin, freeze, unmatch or report, or swipe right to pin (up to 3) or freeze. Frozen connections are skipped by auto-release while you keep talking.")
                }
                .listRowBackground(Palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.midnight)
            .navigationTitle("Connections")
            .navigationDestination(isPresented: $app.showLikesYou) {
                LikesYouView()
            }
            .navigationDestination(for: MatchSummary.self) { match in
                ChatView(match: match) {
                    Task { await model.load(using: app.backend) }
                }
            }
            .refreshable { await model.load(using: app.backend) }
            .overlay {
                if model.isLoading && !model.hasLoaded {
                    ProgressView()
                }
            }
            .confirmationDialog(
                "Unmatch \(pendingUnmatch?.displayName ?? "")?",
                isPresented: Binding(get: { pendingUnmatch != nil }, set: { if !$0 { pendingUnmatch = nil } }),
                titleVisibility: .visible,
                presenting: pendingUnmatch
            ) { match in
                Button("Unmatch", role: .destructive) {
                    Task {
                        await model.unmatch(match, using: app.backend)
                        exitSurveyFor = match
                        app.matchesDidChange()
                    }
                }
            } message: { _ in
                Text("This frees a spot. You won't see each other again.")
            }
        }
        .sheet(item: $reportTarget) { match in
            ReportSheet(
                name: match.displayName,
                onSubmit: { reason, details in
                    try await app.backend.report(
                        userID: match.otherUserID, reason: reason, details: details, matchID: match.matchID
                    )
                },
                onDone: { app.matchesDidChange() }
            )
        }
        .sheet(item: $exitSurveyFor) { match in
            ExitSurveySheet(name: match.displayName) { reason in
                if let reason {
                    Task { try? await app.backend.submitExitFeedback(matchID: match.matchID, reason: reason) }
                }
            }
        }
        .task(id: app.matchesVersion) {
            await model.load(using: app.backend)
            app.openLaunchChatIfNeeded(from: model.pinnedMatches + model.conversations)
        }
        .alert(
            "Couldn't do that",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func conversationRow(_ match: MatchSummary) -> some View {
        NavigationLink(value: match) {
            MatchRow(
                match: match,
                imageURL: model.avatarURL(for: match),
                isNextToRelease: model.isNextToRelease(match),
                isPinned: model.isPinned(match)
            )
        }
        .contextMenu { actions(for: match) }
        .swipeActions(edge: .trailing) {
            Button("Unmatch", systemImage: "xmark.circle", role: .destructive) {
                pendingUnmatch = match
            }
        }
        .swipeActions(edge: .leading) {
            pinButton(match)
                .tint(Palette.amber)
            freezeButton(match)
                .tint(Color(hex: 0x7AF0FF))
        }
    }

    /// Long-press on anyone in Connections.
    @ViewBuilder
    private func actions(for match: MatchSummary) -> some View {
        pinButton(match)
        freezeButton(match)
        Divider()
        Button("Unmatch", systemImage: "xmark.circle", role: .destructive) {
            pendingUnmatch = match
        }
        Button("Report or block", systemImage: "flag", role: .destructive) {
            reportTarget = match
        }
    }

    /// Past the free freeze, trying again opens Glimpse+.
    private func freezeButton(_ match: MatchSummary) -> some View {
        Button(match.isFrozen == true ? "Unfreeze" : "Freeze", systemImage: "snowflake") {
            Task {
                do {
                    try await model.toggleFreeze(match, using: app.backend)
                    app.matchesDidChange()
                } catch GlimpseError.freezeLimit {
                    app.paywall = .freeze
                } catch {
                    model.errorMessage = GlimpseError.describe(error)
                }
            }
        }
    }

    private func pinButton(_ match: MatchSummary) -> some View {
        let pinned = model.isPinned(match)
        return Button(pinned ? "Unpin" : "Pin", systemImage: pinned ? "pin.slash" : "pin") {
            Task { await model.togglePin(match, using: app.backend) }
        }
        .accessibilityIdentifier("matches.pin")
    }
}

private struct SecondChanceRow: View {
    let request: SecondChance
    let onAnswer: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: request.profile.displayName, size: 44, ringColor: Palette.violet)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(request.profile.displayName) wants a second chance")
                    .font(.subheadline.weight(.semibold))
                Text("Your connection ended when their circle was full.")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Button("Pass", systemImage: "xmark") { onAnswer(false) }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
            Button("Accept", systemImage: "heart.fill") { onAnswer(true) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderedProminent)
                .tint(Palette.mint)
        }
        .padding(.vertical, 4)
    }
}

private struct LikedYouCard: View {
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Palette.brandGradient)
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(count == 1 ? "1 person liked you" : "\(count) people liked you")
                    .font(.glimpseHeadline)
                    .foregroundStyle(Palette.textPrimary)
                Text("Like them back and it's an instant match.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Palette.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(Palette.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.pink.opacity(0.4)))
        .accessibilityElement(children: .combine)
    }
}

private struct NoticeRow: View {
    let notice: AppNotification
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(Palette.textSecondary)
            Text(notice.body)
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .foregroundStyle(Palette.textTertiary)
                .buttonStyle(.plain)
        }
    }
}

private struct CapacityHeader: View {
    let active: Int
    let cap: Int

    private var openSpots: Int { max(cap - active, 0) }

    var body: some View {
        HStack(spacing: 18) {
            CapacityRing(active: active, cap: cap, diameter: 76, lineWidth: 7)
            VStack(alignment: .leading, spacing: 4) {
                Text(openSpots == 0 ? "Your circle is full" : "\(openSpots) open \(openSpots == 1 ? "spot" : "spots")")
                    .font(.glimpseTitle2)
                Text(openSpots == 0
                     ? "Your next match will release your quietest connection. Keep the good ones talking."
                     : "Glimpse keeps up to \(cap) connections. Quiet ones make room for new ones.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: .rect(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.stroke))
        .accessibilityElement(children: .combine)
    }
}

private struct NewMatchBubble: View {
    let match: MatchSummary
    let imageURL: URL?

    var body: some View {
        VStack(spacing: 6) {
            AvatarView(name: match.displayName, imageURL: imageURL, size: 68, ringColor: Palette.mint)
            Text(match.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.top, 6)
        .accessibilityLabel("New match with \(match.displayName)")
    }
}

private struct MatchRow: View {
    let match: MatchSummary
    let imageURL: URL?
    let isNextToRelease: Bool
    var isPinned = false

    private var isQuiet: Bool {
        Date.now.timeIntervalSince(match.lastActivity) > 5 * 86_400
    }

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(
                name: match.displayName,
                imageURL: imageURL,
                size: 56,
                ringColor: isNextToRelease ? Palette.pink : nil
            )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(match.displayName)
                        .font(.glimpseHeadline)
                        .foregroundStyle(Palette.textPrimary)
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.amber)
                            .accessibilityLabel("Pinned")
                    }
                    if match.isFrozen == true {
                        Image(systemName: "snowflake")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(hex: 0x7AF0FF))
                            .accessibilityLabel("Frozen")
                    }
                    if match.vibeVerified == true {
                        Tag(text: "Vibe Verified", color: Palette.mint)
                    } else if isNextToRelease {
                        Tag(text: "Next to release", color: Palette.pink)
                    } else if isQuiet {
                        Tag(text: "Quiet", color: Palette.amber)
                    }
                    Spacer()
                    Text(match.lastActivity, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                        .font(.caption)
                        .foregroundStyle(Palette.textTertiary)
                }
                HStack {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(match.unreadCount > 0 ? Palette.textPrimary : Palette.textSecondary)
                        .fontWeight(match.unreadCount > 0 ? .semibold : .regular)
                        .lineLimit(1)
                    Spacer()
                    if match.unreadCount > 0 {
                        Text("\(match.unreadCount)")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(Palette.onMint)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Palette.mint, in: .capsule)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var preview: String {
        guard let body = match.lastMessageBody else { return "Say hi 👋" }
        return match.lastMessageMine == true ? "You: \(body)" : body
    }
}

private struct Tag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: .capsule)
    }
}
