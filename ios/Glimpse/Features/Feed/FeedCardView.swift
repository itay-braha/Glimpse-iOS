import SwiftUI

/// One full-screen profile: looping video (muted until the viewer unmutes), or a
/// linked Instagram/TikTok post in the platform's own player; story-style
/// segments for multiple clips, verified recency tag and a TikTok-style action rail.
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
    @State private var burstID = 0
    @State private var showMeMarker = false
    @State private var preferences = PlaybackPreferences.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var video: ProfileVideo? {
        profile.videos.indices.contains(videoIndex) ? profile.videos[videoIndex] : profile.videos.first
    }

    var body: some View {
        ZStack {
            poster

            if let video, let path = video.storagePath, let url = playableURLs[path] {
                LoopingVideoPlayer(url: url, isActive: isActive, isMuted: preferences.isMuted)
                    .id(video.id)
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
                EmbedStage(link: link, isActive: isActive)
                    .id(video?.id)
                    .padding(.top, insets.top + (profile.videos.count > 1 ? 78 : 64))
                    .padding(.horizontal, 30)
                    .padding(.bottom, insets.bottom + 240)
            }

            VStack(spacing: 0) {
                if profile.videos.count > 1 {
                    segments
                        .padding(.top, insets.top + 60)
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

            HeartBurst(trigger: burstID, reduceMotion: reduceMotion)
                .allowsHitTesting(false)
        }
        .clipped()
        .task(id: "\(isActive)-\(videoIndex)") {
            // The "Me" ring shows for the first few seconds of each clip.
            guard isActive else {
                showMeMarker = false
                return
            }
            withAnimation(.easeOut(duration: 0.3)) { showMeMarker = true }
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeIn(duration: 0.4)) { showMeMarker = false }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Like") { like() }
        .accessibilityAction(named: "Pass", onPass)
        .accessibilityAction(named: "Next clip") { step(1) }
        .accessibilityAction(named: "Previous clip") { step(-1) }
    }

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

    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(profile.videos.indices, id: \.self) { index in
                Capsule()
                    .fill(index == videoIndex ? Palette.textPrimary : Palette.textPrimary.opacity(0.3))
                    .frame(height: 3)
            }
        }
        .accessibilityHidden(true)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let prompt = video?.prompt {
                PromptSticker(prompt: prompt)
            }
            if let video {
                RecencyBadge(video: video)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(profile.displayName)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                Text("\(profile.age)")
                    .font(.system(.title, design: .rounded, weight: .medium))
                    .foregroundStyle(Palette.textPrimary.opacity(0.85))
                if profile.isVerified == true {
                    VerifiedBadge()
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            HStack(spacing: 12) {
                if let city = profile.city {
                    Label(city, systemImage: "location.fill")
                }
                if let km = profile.distanceKm {
                    Text(km <= 1 ? "Under 1 km away" : "\(km) km away")
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
        .accessibilityElement(children: .combine)
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

    private func step(_ delta: Int) {
        guard profile.videos.count > 1 else { return }
        let next = videoIndex + delta
        videoIndex = min(max(next, 0), profile.videos.count - 1)
    }

    private func like() {
        burstID += 1
        guard !isLiked else { return }
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
                Text(title)
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
