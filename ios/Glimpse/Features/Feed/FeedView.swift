import SwiftUI

struct FeedView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = FeedModel()
    @State private var reportTarget: FeedProfile?
    @State private var capacityPrompt: FeedProfile?
    @State private var skipCapacityPrompt = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Palette.midnight.ignoresSafeArea()

                if model.profiles.isEmpty {
                    emptyState
                } else {
                    cards(insets: proxy.safeAreaInsets)
                }

                topBar
                    .padding(.top, proxy.safeAreaInsets.top > 0 ? 0 : 12)
            }
        }
        .overlay {
            if let celebration = model.celebration {
                MatchCelebrationView(
                    celebration: celebration,
                    myName: app.profile?.displayName ?? "You",
                    onMessage: {
                        let match = celebration.match
                        model.dismissCelebration()
                        app.openChat(match)
                    },
                    onDismiss: { model.dismissCelebration() }
                )
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
            }
        }
        .animation(.smooth(duration: 0.35), value: model.celebration)
        .toolbar(model.celebration == nil ? .visible : .hidden, for: .tabBar)
        .sheet(item: $capacityPrompt) { profile in
            if let next = model.capacity.nextToBoot {
                CapacityConfirmSheet(
                    candidateName: profile.displayName,
                    next: next,
                    canFreeze: true,
                    onLikeAnyway: {
                        skipCapacityPrompt = true
                        performLike(profile)
                    },
                    onFreezeThenLike: {
                        Task {
                            do {
                                try await app.backend.setFrozen(next.matchID, frozen: true)
                                await model.refreshCapacity(using: app.backend)
                                performLike(profile)
                            } catch GlimpseError.freezeLimit {
                                app.paywall = .freeze
                            } catch {
                                model.errorMessage = GlimpseError.describe(error)
                            }
                        }
                    },
                    onChatFirst: {
                        Task {
                            if let match = try? await app.backend.fetchMatches().first(where: { $0.matchID == next.matchID }) {
                                app.openChat(match)
                            }
                        }
                    }
                )
            }
        }
        .sheet(item: $reportTarget) { profile in
            ReportSheet(name: profile.displayName) { reason, details in
                try await app.backend.report(userID: profile.id, reason: reason, details: details, matchID: nil)
                model.remove(profile.id)
            }
        }
        .task {
            FeedSignals.shared.configure(app.backend)
            guard !model.hasLoaded else { return }
            await model.load(using: app.backend)
            if app.launch.screen == .match, let first = model.profiles.first {
                _ = await model.like(first, using: app.backend)
            }
            await app.didBecomeReady()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { FeedSignals.shared.flush() }
        }
        .onDisappear { FeedSignals.shared.flush() }
        .onChange(of: model.currentID) { _, newValue in
            model.visibleProfileChanged(to: newValue, using: app.backend)
        }
        .onChange(of: app.matchesVersion) {
            Task {
                await model.refreshCapacity(using: app.backend)
                await model.refreshQuota(using: app.backend)
            }
        }
        .onChange(of: app.paywall) { _, newValue in
            if newValue == nil {
                Task { await model.refreshQuota(using: app.backend) }
            }
        }
    }

    private func cards(insets: EdgeInsets) -> some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(model.profiles) { profile in
                    FeedCardView(
                        profile: profile,
                        playableURLs: model.playableURLs,
                        isActive: model.currentID == profile.id && model.celebration == nil,
                        isLiked: model.likedIDs.contains(profile.id),
                        insets: insets,
                        onLike: { like(profile) },
                        onPass: { model.pass(profile, using: app.backend) },
                        onReport: { reportTarget = profile }
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(profile.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $model.currentID)
        .scrollIndicators(.hidden)
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.4), value: model.currentID)
    }

    private var topBar: some View {
        HStack {
            Wordmark(size: 26)
            Spacer()
            if let quota = model.quota, !quota.isPlus, quota.remaining <= 5 {
                LikesLeftPill(remaining: quota.remaining) {
                    app.paywall = .outOfLikes
                }
            }
            CapacityPill(active: model.capacity.active, cap: model.capacity.cap)
        }
        .padding(.horizontal, 18)
        .overlay(alignment: .bottom) {
            if model.capacity.atCapacity, let next = model.capacity.nextToBoot {
                CapacityNotice(nextName: next.displayName)
                    .offset(y: 46)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let until = model.pausedUntil, !model.isLoading {
            PausedFeedView(until: until) {
                Task { await model.resume(using: app.backend) }
            }
        } else if !model.density.unlocked, !model.isLoading {
            DensityGateView(status: model.density) {
                Task { await model.load(using: app.backend) }
            }
        } else if model.viewsExhausted, !model.isLoading {
            OutOfGlimpsesView(
                resetsAt: model.quota?.viewsResetAt,
                isPlus: model.quota?.isPlus == true,
                onConnections: { app.selectedTab = .connections },
                onUpgrade: { app.paywall = .outOfViews }
            )
        } else {
            caughtUp
        }
    }

    private var caughtUp: some View {
        VStack(spacing: 16) {
            Spacer()
            if model.isLoading {
                ProgressView().controlSize(.large)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 44))
                    .foregroundStyle(Palette.brandGradient)
                Text(model.errorMessage == nil ? "You're all caught up" : "Couldn't load your feed")
                    .font(.glimpseTitle2)
                Text(model.errorMessage ?? "New people join every day. In the meantime, keep your conversations alive.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.textSecondary)
                Button("Refresh") {
                    Task { await model.load(using: app.backend) }
                }
                .buttonStyle(.glimpseSecondary)
                .frame(maxWidth: 220)
                .padding(.top, 8)
            }
            Spacer()
        }
        .padding(32)
    }

    /// At capacity, liking someone is a choice about who might be released.
    private func like(_ profile: FeedProfile) {
        if model.capacity.atCapacity, model.capacity.nextToBoot != nil, !skipCapacityPrompt,
           !model.likedIDs.contains(profile.id) {
            capacityPrompt = profile
            return
        }
        performLike(profile)
    }

    private func performLike(_ profile: FeedProfile) {
        Task {
            switch await model.like(profile, using: app.backend) {
            case .matched:
                app.track("match_created")
                app.matchesDidChange()
            case .liked:
                app.track("profile_liked")
            case .outOfLikes:
                app.track("out_of_likes")
                app.paywall = .outOfLikes
            case .outOfViews:
                app.track("out_of_views")
            case .failed:
                break
            }
        }
    }
}

/// Appears when a free user is down to their last few daily likes.
private struct LikesLeftPill: View {
    let remaining: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(remaining == 0 ? "No likes left" : "\(remaining) left", systemImage: "heart.fill")
                .font(.glimpseCaption)
                .foregroundStyle(remaining == 0 ? Palette.pink : Palette.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(remaining == 0 ? "No likes left today. Learn about Glimpse Plus" : "\(remaining) likes left today")
    }
}

/// Shown while the user is at 20/20: liking someone can release the quietest connection.
private struct CapacityNotice: View {
    let nextName: String

    var body: some View {
        Label {
            Text("At 20. A new match releases **\(nextName)**, your quietest chat.")
        } icon: {
            Image(systemName: "arrow.triangle.2.circlepath")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Palette.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Palette.pink.opacity(0.22), in: .capsule)
        .overlay(Capsule().strokeBorder(Palette.pink.opacity(0.5), lineWidth: 1))
        .background(.ultraThinMaterial, in: .capsule)
    }
}
