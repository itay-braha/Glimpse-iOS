import SwiftUI

/// Full-screen look at one of my clips, with tools: tag myself ("It's me"),
/// change the vibe prompt, and export a watermarked copy to share. Linked
/// Instagram/TikTok posts play in the platform's player and only take a prompt.
struct VideoPreviewView: View {
    let video: ProfileVideo
    let url: URL?
    let shareCaption: String
    let onUpdate: (VibePrompt?, CGPoint?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isTagging = false
    @State private var marker: CGPoint?
    @State private var prompt: VibePrompt?
    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var errorMessage: String?
    @State private var preferences = PlaybackPreferences.shared

    init(video: ProfileVideo, url: URL?, shareCaption: String, onUpdate: @escaping (VibePrompt?, CGPoint?) -> Void) {
        self.video = video
        self.url = url
        self.shareCaption = shareCaption
        self.onUpdate = onUpdate
        // One-time seeds for the editor.
        _marker = State(initialValue: video.meMarkerX.flatMap { x in video.meMarkerY.map { CGPoint(x: x, y: $0) } })
        _prompt = State(initialValue: video.prompt)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                if let link = video.embedLink {
                    EmbedStage(link: link)
                        .padding(.top, 72)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 150)
                } else if let url {
                    LoopingVideoPlayer(url: url, isActive: true, isMuted: preferences.isMuted)
                        .ignoresSafeArea()
                }
                if let marker {
                    MeMarkerRing()
                        .position(x: proxy.size.width * marker.x, y: proxy.size.height * marker.y + 14)
                }
                if isTagging {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .contentShape(.rect)
                        .onTapGesture(coordinateSpace: .local) { location in
                            let point = CGPoint(
                                x: min(max(location.x / proxy.size.width, 0), 1),
                                y: min(max(location.y / proxy.size.height, 0), 1)
                            )
                            marker = point
                            isTagging = false
                            onUpdate(prompt, point)
                        }
                        .overlay {
                            Text("Tap yourself in the video")
                                .font(.glimpseHeadline)
                                .padding(12)
                                .background(.ultraThinMaterial, in: .capsule)
                                .allowsHitTesting(false)
                        }
                }
            }
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { tools }
    }

    private var topBar: some View {
        HStack {
            if let prompt {
                PromptSticker(prompt: prompt)
            }
            Spacer()
            if !video.isEmbed {
                MuteToggle()
            }
            Button("Close", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: .circle)
        }
        .padding()
    }

    private var tools: some View {
        VStack(spacing: 12) {
            if video.isUnavailable, let link = video.embedLink {
                Label("This \(link.platform.name) post was deleted, made private or expired, so others can't see it. Remove it and add a fresh moment.", systemImage: "eye.slash.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Palette.pink.opacity(0.85), in: .rect(cornerRadius: 14))
            }
            if let errorMessage { ErrorText(errorMessage) }
            RecencyBadge(video: video)
            HStack(spacing: 10) {
                if !video.isEmbed {
                    Button(marker == nil ? "Tag me" : "Move tag", systemImage: "person.crop.circle.badge.checkmark") {
                        isTagging = true
                    }
                }
                Menu {
                    Button("No prompt") { setPrompt(nil) }
                    ForEach(VibePrompt.allCases) { option in
                        Button(option.text) { setPrompt(option) }
                    }
                } label: {
                    Label("Prompt", systemImage: "quote.bubble")
                }
                if let link = video.embedLink {
                    ShareLink(item: link.canonicalURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } else if let exportedURL {
                    ShareLink(item: exportedURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button(isExporting ? "Preparing…" : "Share", systemImage: "square.and.arrow.up") {
                        Task { await export() }
                    }
                    .disabled(isExporting || url == nil)
                }
            }
            .buttonStyle(.bordered)
            .tint(.white)
            if marker != nil {
                Button("Remove tag") {
                    marker = nil
                    onUpdate(prompt, nil)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(20)
    }

    private func setPrompt(_ newValue: VibePrompt?) {
        prompt = newValue
        onUpdate(newValue, marker)
    }

    private func export() async {
        guard let url else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            exportedURL = try await VideoWatermarker.export(url, caption: shareCaption)
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }
}
