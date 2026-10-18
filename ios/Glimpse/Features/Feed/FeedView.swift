import Combine
import SwiftUI
import UIKit

struct FeedView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = FeedModel()
    @AppStorage("glimpse.feedTipsSeen") private var tipsSeen = false
    @State private var reportTarget: FeedProfile?
    @State private var capacityPrompt: FeedProfile?
    @State private var skipCapacityPrompt = false
    @State private var showLikesInfo = false
    @State private var admirerCount = 0
    @State private var rewindNotice: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Palette.midnight.ignoresSafeArea()

                if model.profiles.isEmpty {
                    emptyState
                } else {
                    cards(insets: proxy.safeAreaInsets)
                    if showTips {
                        FeedTipsOverlay { tipsSeen = true }
                            .transition(.opacity)
                            .zIndex(10)
                    }
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
        .alert(
            String(localized: "Rewind"),
            isPresented: Binding(get: { rewindNotice != nil }, set: { if !$0 { rewindNotice = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rewindNotice ?? "")
        }
        .sheet(isPresented: $showLikesInfo) {
            OutOfLikesSheet(
                resetsAt: model.quota?.resetsAt,
                admirers: admirerCount,
                onSeeAdmirers: {
                    app.selectedTab = .connections
                    app.showLikesYou = true
                },
                onSeeGold: {
                    // Let this sheet finish closing before the paywall opens.
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        app.paywall = .gold
                    }
                }
            )
        }
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
            ReportSheet(
                name: profile.displayName,
                onSubmit: { reason, details in
                    try await app.backend.report(userID: profile.id, reason: reason, details: details, matchID: nil)
                },
                onDone: { model.remove(profile.id) }
            )
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

    /// Once per install (scripted screenshot runs skip it unless `-showTips`).
    private var showTips: Bool {
        !tipsSeen && (app.launch.screen == nil || app.launch.showTips)
    }

    private func cards(insets: EdgeInsets) -> some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(model.profiles) { profile in
                    FeedCardView(
                        profile: profile,
                        playableURLs: model.playableURLs,
                        isActive: model.currentID == profile.id && model.celebration == nil && !showTips,
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

    /// Glimpse Gold brings back the last pass; everyone else sees what Gold offers.
    private func rewind() async {
        do {
            if try await model.rewind(using: app.backend) {
                app.track("rewind_used")
                // Quiet until the end, like the like counter.
                let left = (try? await app.backend.goldStatus().rewindsLeft) ?? 5
                if left <= 1 {
                    rewindNotice = left == 0 ? String(localized: "That was your last rewind today. More tomorrow.") : String(localized: "1 rewind left today.")
                }
            } else {
                rewindNotice = String(localized: "There's nobody to bring back right now.")
            }
        } catch GlimpseError.goldRequired {
            app.paywall = .gold
        } catch GlimpseError.rewindLimit {
            rewindNotice = String(localized: "You've used today's 5 rewinds. They come back tomorrow.")
        } catch {
            rewindNotice = GlimpseError.describe(error)
        }
    }

    /// Out of likes (or tapping the counter): the "you're out" sheet, with how many
    /// admirers are waiting, since liking them back is free.
    private func showOutOfLikes() {
        Task {
            await model.refreshQuota(using: app.backend)
            admirerCount = (try? await app.backend.likesReceived().total) ?? 0
            showLikesInfo = true
        }
    }

    private var topBar: some View {
        HStack {
            Wordmark(size: 26)
            Spacer()
            Button("Rewind", systemImage: "arrow.uturn.backward") {
                Task { await rewind() }
            }
            .labelStyle(.iconOnly)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Palette.amber)
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial, in: .circle)
            .accessibilityIdentifier("feed.rewind")
            // Quiet until the last few, like the big apps.
            if let quota = model.quota, quota.remaining <= 3 {
                LikesLeftPill(remaining: quota.remaining) {
                    if quota.remaining == 0 { showOutOfLikes() }
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
            } onShareLocation: {
                Task {
                    if let spot = await LocationService.approximateCoordinate() {
                        try? await app.backend.updateLocation(latitude: spot.latitude, longitude: spot.longitude)
                    }
                    await model.load(using: app.backend)
                }
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
                Text(model.errorMessage == nil ? String(localized: "You're all caught up") : String(localized: "Couldn't load your feed"))
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
                await app.offerAlerts(.newMatch, name: profile.displayName)
            case .liked:
                app.track("profile_liked")
            case .outOfLikes:
                app.track("out_of_likes")
                showOutOfLikes()
            case .outOfViews:
                app.track("out_of_views")
            case .failed:
                break
            }
        }
    }
}

/// Appears when someone is down to their last few daily likes.
private struct LikesLeftPill: View {
    let remaining: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: remaining == 0 ? "heart.slash.fill" : "heart.fill")
                .font(.glimpseCaption)
                .foregroundStyle(remaining == 0 ? Palette.pink : Palette.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(remaining == 0 ? String(localized: "No likes left today") : String(localized: "\(remaining) likes left today"))
        .accessibilityIdentifier("feed.likesLeft")
    }

    private var title: String {
        switch remaining {
        case 0: String(localized: "No likes left")
        case 1: String(localized: "Last like today")
        default: String(localized: "\(remaining) likes left")
        }
    }
}

/// Shown while the user is at 15/15: liking someone can release the quietest connection.
private struct CapacityNotice: View {
    let nextName: String

    var body: some View {
        Label {
            Text("At \(MatchesModel.cap). A new match releases **\(nextName)**, your quietest chat.")
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
