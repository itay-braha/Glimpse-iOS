import SwiftUI

/// One full-screen profile.
///
/// How people move around (the same wherever a card appears):
///   * swipe right = like, swipe left = pass;
///   * swipe up / down = next / previous person (the feed's paging);
///   * tap the right / left side = that person's next / previous clip;
///   * clips play for the viewer's clip time (7 s by default, 5–15 in Settings),
///     then move to the person's next clip, looping back to the first after the
///     last; a longer clip shows "+Ns" to watch the rest.
/// Hosted clips start muted; linked Instagram/TikTok posts play in the platform's
/// own player and only advance when tapped.
struct FeedCardView: View {
    let profile: FeedProfile
    let playableURLs: [String: URL]
    let isActive: Bool
    let isLiked: Bool
    let insets: EdgeInsets
    let onLike: () -> Void
    let onPass: () -> Void
    let onReport: () -> Void

    @State private var videoIndex = 0
    /// Bumped to replay a clip from the start (single-clip profiles, loops).
    @State private var playCycle = 0
    /// The viewer tapped "+Ns" to watch the rest of this clip.
    @State private var showFullClip = false
    @State private var clipStartedAt = Date.now
    @State private var burstID = 0
    @State private var showMeMarker = false
    @State private var dragX: CGFloat = 0
    @State private var preferences = PlaybackPreferences.shared
    @State private var health = EmbedHealth.shared
    @AppStorage(PlaybackPreferences.clipSecondsKey) private var clipSeconds = PlaybackPreferences.defaultClipSeconds
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    private static let swipeThreshold: CGFloat = 110

    private var video: ProfileVideo? {
        videos.indices.contains(videoIndex) ? videos[videoIndex] : videos.last
    }

    /// Clips this viewer can actually play: a linked post their player found dead
    /// drops out on the spot (the hosted anchor clip always remains).
    private var videos: [ProfileVideo] {
        profile.videos.filter { !health.deadForMe.contains($0.id) }
    }

    /// How long the current clip shows before moving on (nil for linked posts).
    private var clipLimit: Double? {
        guard let video, !video.isEmbed else { return nil }
        let length = video.durationSeconds ?? 15
        return showFullClip ? length : min(clipSeconds, length)
    }

    /// The hosted clip on screen (linked posts play in their platform's own player).
    private var sensitiveCheckURL: URL? {
        video?.storagePath.flatMap { playableURLs[$0] }
    }

    /// Seconds left after the clip time, offered behind "+Ns".
    private var moreSeconds: Int {
        guard let length = video?.durationSeconds, video?.isEmbed == false, !showFullClip else { return 0 }
        let extra = length - clipSeconds
        return extra >= 1 ? Int(extra.rounded()) : 0
    }

    var body: some View {
        ZStack {
            // Viewers with Sensitive Content Warning on get a warning over possible nudity.
            SensitiveVideoGate(url: sensitiveCheckURL) {
            ZStack {
            poster

            if let video, let path = video.storagePath, let url = playableURLs[path] {
                LoopingVideoPlayer(url: url, isActive: isActive, isMuted: preferences.isMuted)
                    .id("\(video.id)-\(playCycle)")
                    .allowsHitTesting(false)
            }

            if showMeMarker, let video, let x = video.meMarkerX, let y = video.meMarkerY {
                GeometryReader { proxy in
                    MeMarkerRing()
                        .position(x: proxy.size.width * x, y: proxy.size.height * y + 14)
                }
                .transition(.opacity)
            }

            VStack(spacing: 0) {
                GradientScrim(edge: .top, height: 200, strength: 0.6)
                Spacer()
                GradientScrim(edge: .bottom, height: 480, strength: 0.9)
            }
            .allowsHitTesting(false)

            gestureLayer

            if let link = video?.embedLink {
                // Linked post: framed above the name block so the platform's own
                // player and captions stay readable and tappable.
                EmbedStage(link: link, isActive: isActive, videoID: video?.id) {
                    FeedSignals.shared.record(.linkOpen, target: profile.id)
                }
                .id(video?.id)
                // Clear of the header/capacity banner above and the action rail on the right.
                .padding(.top, insets.top + 124)
                .padding(.leading, 16)
                .padding(.trailing, 88)
                .padding(.bottom, insets.bottom + 236)
            }

            VStack(spacing: 0) {
                // Below the feed's header and capacity banner, so nothing covers them.
                if videos.count > 1 || clipLimit != nil {
                    segments
                        .padding(.top, insets.top + 112)
                        .padding(.horizontal, 14)
                }
                Spacer()
                HStack(alignment: .bottom, spacing: 16) {
                    info
                    Spacer(minLength: 0)
                    actionRail
                }
                .padding(.horizontal, 16)
                .padding(.bottom, insets.bottom + 18)
            }

            }
            }
            // Content follows the reading direction (in Hebrew, tapping left is the next clip);
            // swipes stay physical everywhere: right is like, left is pass.
            .environment(\.layoutDirection, layoutDirection)

            swipeStamp

            HeartBurst(trigger: burstID, reduceMotion: reduceMotion)
                .allowsHitTesting(false)
        }
        .offset(x: dragX)
        .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragX / 30)), anchor: .bottom)
        .simultaneousGesture(swipeGesture)
        .environment(\.layoutDirection, .leftToRight)
        .onChange(of: preferences.isMuted) { _, muted in
            if isActive, !muted { FeedSignals.shared.record(.unmute, target: profile.id) }
        }
        .clipped()
        .task(id: "\(isActive)-\(videoIndex)-\(playCycle)-\(showFullClip)") {
            await runClip()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Like") { like() }
        .accessibilityAction(named: "Pass", onPass)
        .accessibilityAction(named: "Next clip") { step(1) }
        .accessibilityAction(named: "Previous clip") { step(-1) }
    }

    // MARK: Clip rhythm

    /// Shows the "Me" ring briefly, then moves on when the clip time is up.
    private func runClip() async {
        guard isActive else {
            showMeMarker = false
            return
        }
        if !showFullClip {
            clipStartedAt = .now
            if let video { FeedSignals.shared.record(.clipShown, target: profile.id, video: video.id) }
        }
        withAnimation(.easeOut(duration: 0.3)) { showMeMarker = true }
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeIn(duration: 0.4)) { showMeMarker = false }
        }
        guard let limit = clipLimit else { return }
        let remaining = limit - Date.now.timeIntervalSince(clipStartedAt)
        try? await Task.sleep(for: .seconds(max(remaining, 0.1)))
        guard !Task.isCancelled else { return }
        advanceAutomatically()
    }

    /// After the clip time: the person's next clip, or back to the first after the last.
    private func advanceAutomatically() {
        if let video { FeedSignals.shared.record(.clipComplete, target: profile.id, video: video.id) }
        showFullClip = false
        if videos.count > 1 {
            videoIndex = (videoIndex + 1) % videos.count
            if videoIndex == 0 { playCycle += 1 }
        } else {
            playCycle += 1
        }
    }

    private func step(_ delta: Int) {
        guard videos.count > 1 else { return }
        let next = min(max(videoIndex + delta, 0), videos.count - 1)
        if next > videoIndex { FeedSignals.shared.record(.clipNext, target: profile.id, video: video?.id) }
        showFullClip = false
        videoIndex = next
    }

    // MARK: Swipes

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                // Horizontal swipes only; vertical ones page between people.
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height) * 1.2 else { return }
                dragX = dx
            }
            .onEnded { value in
                let dx = dragX
                let flung = value.predictedEndTranslation.width
                let horizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                if horizontal, dx > Self.swipeThreshold || flung > 260 {
                    finishSwipe(liked: true)
                } else if horizontal, dx < -Self.swipeThreshold || flung < -260 {
                    finishSwipe(liked: false)
                } else {
                    withAnimation(.spring(duration: 0.3, bounce: 0.3)) { dragX = 0 }
                }
            }
    }

    private func finishSwipe(liked: Bool) {
        withAnimation(.easeIn(duration: 0.18)) { dragX = liked ? 500 : -500 }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            if liked { like() } else { onPass() }
            withAnimation(.spring(duration: 0.35)) { dragX = 0 }
        }
    }

    private var swipeStamp: some View {
        let progress = min(abs(dragX) / Self.swipeThreshold, 1)
        let liking = dragX > 0
        return Text(liking ? "LIKE" : "PASS")
            .font(.system(size: 44, weight: .black, design: .rounded))
            .foregroundStyle(liking ? Palette.mint : Palette.pink)
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(liking ? Palette.mint : Palette.pink, lineWidth: 5))
            .rotationEffect(.degrees(liking ? -14 : 14))
            .opacity(Double(progress))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: liking ? .topLeading : .topTrailing)
            .padding(.top, insets.top + 120)
            .padding(.horizontal, 36)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Pieces

    private var poster: some View {
        ZStack {
            Palette.seededGradient(profile.displayName)
            Text(String(profile.displayName.prefix(1)))
                .font(.system(size: 220, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.08))
        }
        .accessibilityHidden(true)
    }

    /// Tap left/right halves to step between clips, double-tap to like. Over an
    /// embed only the side gutters do this; the middle belongs to the player.
    private var gestureLayer: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(.rect)
                .onTapGesture(count: 2) { like() }
                .onTapGesture { step(-1) }
                .frame(maxWidth: video?.isEmbed == true ? 30 : .infinity)
            if video?.isEmbed == true {
                Spacer()
            }
            Color.clear
                .contentShape(.rect)
                .onTapGesture(count: 2) { like() }
                .onTapGesture { step(1) }
                .frame(maxWidth: video?.isEmbed == true ? 30 : .infinity)
        }
        .accessibilityHidden(true)
    }

    /// Story-style bars: done clips full, the current one filling over its clip time.
    private var segments: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isActive || clipLimit == nil)) { context in
            HStack(spacing: 4) {
                ForEach(videos.indices, id: \.self) { index in
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Palette.textPrimary.opacity(0.3))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Palette.textPrimary)
                                    .frame(width: proxy.size.width * fill(for: index, at: context.date))
                            }
                    }
                    .frame(height: 3)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Clip \(videoIndex + 1) of \(videos.count)")
        .accessibilityIdentifier(isActive ? "clipPosition.active" : "clipPosition")
    }

    private func fill(for index: Int, at date: Date) -> CGFloat {
        if index < videoIndex { return 1 }
        if index > videoIndex { return 0 }
        guard let limit = clipLimit, limit > 0 else { return 1 }
        return CGFloat(min(max(date.timeIntervalSince(clipStartedAt) / limit, 0), 1))
    }

    private var moreButton: some View {
        Button {
            showFullClip = true
            if let video { FeedSignals.shared.record(.clipMore, target: profile.id, video: video.id) }
        } label: {
            Label("+\(moreSeconds)s more", systemImage: "forward.fill")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.4), in: .capsule)
                .overlay(Capsule().strokeBorder(.white.opacity(0.2)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Watch the rest of this clip, \(moreSeconds) more seconds")
        .accessibilityIdentifier("watchMore")
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let note = profile.discoveryNote {
                Label(note.text, systemImage: note.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Palette.violet.opacity(0.55), in: .capsule)
                    .accessibilityIdentifier("discoveryNote")
            }
            if let prompt = video?.prompt {
                PromptSticker(prompt: prompt)
            }
            if let video {
                HStack(spacing: 8) {
                    RecencyBadge(video: video)
                    if moreSeconds > 0 {
                        moreButton
                    }
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(profile.displayName)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .accessibilityIdentifier(isActive ? "profileName.active" : "profileName")
                Text("\(profile.age)")
                    .font(.system(.title, design: .rounded, weight: .medium))
                    .foregroundStyle(Palette.textPrimary.opacity(0.85))
                if profile.isVerified == true {
                    VerifiedBadge()
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            if profile.showsUp == true {
                Label("Shows up", systemImage: "calendar.badge.checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.onMint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Palette.mint, in: .capsule)
                    .accessibilityLabel("Shows up to dates")
            }
            HStack(spacing: 12) {
                if let city = profile.city {
                    Label(city, systemImage: "location.fill")
                }
                if let km = profile.distanceKm {
                    Text(km <= 1 ? String(localized: "Under 1 km away") : String(localized: "\(km) km away"))
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.textPrimary.opacity(0.85))
            if let bio = profile.bio {
                Text(bio)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textPrimary.opacity(0.9))
                    .lineLimit(3)
            }
        }
        .foregroundStyle(Palette.textPrimary)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
    }

    private var actionRail: some View {
        VStack(spacing: 22) {
            if video?.isEmbed == false {
                MuteToggle()
            }
            RailButton(
                title: isLiked ? "Liked" : "Glimpse",
                symbol: "heart.fill",
                size: 64,
                foreground: isLiked ? Palette.pink : Palette.onMint,
                background: isLiked ? Color.white : Palette.mint,
                action: like
            )
            RailButton(title: "Pass", symbol: "xmark", size: 52, foreground: .white, background: .white.opacity(0.16), action: onPass)
            RailButton(title: "Report", symbol: "flag.fill", size: 44, foreground: .white, background: .white.opacity(0.12), action: onReport)
        }
    }

    private func like() {
        burstID += 1
        guard !isLiked else { return }
        if let video { FeedSignals.shared.record(.clipLiked, target: profile.id, video: video.id) }
        onLike()
    }
}

private struct RailButton: View {
    let title: String
    let symbol: String
    let size: CGFloat
    let foreground: Color
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(foreground)
                    .frame(width: size, height: size)
                    .background(background, in: .circle)
                    .shadow(color: background.opacity(0.4), radius: 12)
                Text(LocalizedStringKey(title))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct HeartBurst: View {
    let trigger: Int
    let reduceMotion: Bool
    @State private var visible = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 120))
            .foregroundStyle(Palette.brandGradient)
            .shadow(color: Palette.pink.opacity(0.6), radius: 24)
            .scaleEffect(visible ? 1 : 0.4)
            .opacity(visible ? 1 : 0)
            .onChange(of: trigger) {
                guard !reduceMotion else { return }
                withAnimation(.spring(duration: 0.3, bounce: 0.5)) { visible = true }
                Task {
                    try? await Task.sleep(for: .milliseconds(550))
                    withAnimation(.easeOut(duration: 0.25)) { visible = false }
                }
            }
            .accessibilityHidden(true)
    }
}
