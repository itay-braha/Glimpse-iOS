import SwiftUI

struct MyProfileView: View {
    @Environment(AppModel.self) private var app
    @State private var model = ProfileModel()
    @State private var showAddVideo = false
    @State private var showSettings = false
    @State private var previewing: ProfileVideo?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if !model.staleVideos.isEmpty {
                        RotationPrompt(count: model.staleVideos.count) {
                            showAddVideo = true
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Your moments").font(.glimpseTitle2)
                            Spacer()
                            Text("\(model.videos.count) of \(ProfileModel.maxVideos)")
                                .font(.glimpseCaption)
                                .foregroundStyle(Palette.textTertiary)
                        }
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(model.videos) { video in
                                VideoTile(video: video, thumbnailURL: model.url(for: video.thumbnailPath))
                                    .onTapGesture { previewing = video }
                                    .contextMenu {
                                        if video.id != model.videos.first?.id, !video.isEmbed {
                                            Button("Make cover", systemImage: "star") {
                                                Task { await model.makeCover(video, using: app.backend) }
                                            }
                                        }
                                        Button("Remove", systemImage: "trash", role: .destructive) {
                                            Task { await model.delete(video, using: app.backend) }
                                        }
                                    }
                                    .accessibilityAddTraits(.isButton)
                            }
                            if model.canAddVideo {
                                AddVideoTile { showAddVideo = true }
                            }
                        }
                        Text("Every moment shows when it was filmed. Clips from the last 12 months only; after a year you'll see a nudge to refresh. Long-press a clip to make it your cover. Your own clips always come first; linked posts follow.")
                            .font(.footnote)
                            .foregroundStyle(Palette.textTertiary)
                    }

                    if let error = model.errorMessage {
                        ErrorText(error)
                    }

                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                        .buttonStyle(.glimpseSecondary)
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Palette.midnight)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Wordmark(size: 20)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await model.load(using: app.backend)
            if app.launch.screen == .settings { showSettings = true }
            if app.launch.screen == .addVideo { showAddVideo = true }
        }
        .sheet(isPresented: $showAddVideo) {
            AddVideoSheet(canLink: model.canLink) { video in
                Task { await model.added(video, using: app.backend) }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .fullScreenCover(item: $previewing) { video in
            VideoPreviewView(video: video, url: model.url(for: video.storagePath), shareCaption: shareCaption) { prompt, marker in
                Task { await model.updateDetails(video, prompt: prompt, marker: marker, using: app.backend) }
            }
        }
    }

    private var shareCaption: String {
        let name = app.profile?.displayName ?? ""
        let age = app.profile?.age.map { ", \($0)" } ?? ""
        let city = app.profile?.city.map { " · \($0)" } ?? ""
        return name + age + city
    }

    private var header: some View {
        HStack(spacing: 16) {
            AvatarView(
                name: app.profile?.displayName ?? "?",
                imageURL: model.url(for: model.videos.first?.thumbnailPath),
                size: 76,
                ringColor: Palette.violet
            )
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(app.profile?.displayName ?? "")
                        .font(.glimpseTitle)
                    if app.profile?.isVerified == true {
                        VerifiedBadge(size: 20)
                    }
                    if let age = app.profile?.age {
                        Text("\(age)").font(.title2).foregroundStyle(Palette.textSecondary)
                    }
                }
                if let city = app.profile?.city {
                    Label(city, systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                if let bio = app.profile?.bio {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textPrimary.opacity(0.85))
                        .lineLimit(2)
                }
            }
        }
    }
}

private struct RotationPrompt: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundStyle(Palette.pink)
            VStack(alignment: .leading, spacing: 6) {
                Text(count == 1 ? "1 moment is over a year old" : "\(count) moments are over a year old")
                    .font(.glimpseHeadline)
                Text("Fresh clips keep your profile honest and get you seen more.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                Button("Add a fresh moment", action: action)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.pink)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.pink.opacity(0.1), in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.pink.opacity(0.35)))
    }
}

private struct VideoTile: View {
    let video: ProfileVideo
    let thumbnailURL: URL?

    private var isStale: Bool { Recency.isStale(video.capturedAt) }
    private var needsAttention: Bool { isStale || video.isUnavailable }

    var body: some View {
        Color.clear
            .aspectRatio(9 / 16, contentMode: .fit)
            .background {
                ZStack {
                    Palette.seededGradient(video.id.uuidString)
                    if let link = video.embedLink {
                        VStack(spacing: 6) {
                            Image(systemName: video.source.symbolName)
                                .font(.title2)
                            Text(link.platform.name)
                                .font(.caption.weight(.heavy))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                    } else if let thumbnailURL {
                        AsyncImage(url: thumbnailURL) { phase in
                            phase.image?.resizable().scaledToFill()
                        }
                    } else {
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .overlay(alignment: .bottomLeading) {
                RecencyBadge(video: video, compact: true)
                    .padding(6)
            }
            .overlay(alignment: .topTrailing) {
                if video.isUnavailable {
                    Text("Unavailable")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Palette.pink, in: .capsule)
                        .padding(6)
                } else if isStale {
                    Text("Refresh")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Palette.pink, in: .capsule)
                        .padding(6)
                }
            }
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(needsAttention ? Palette.pink : Palette.stroke, lineWidth: needsAttention ? 2 : 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(video.isEmbed ? "\(video.source.displayName) link" : video.source.displayName) moment, \(Recency.label(for: video))\(video.isUnavailable ? ", no longer available, hidden from others" : isStale ? ", needs rotating" : "")")
    }
}

private struct AddVideoTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear
                .aspectRatio(9 / 16, contentMode: .fit)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "plus").font(.title2.weight(.bold))
                        Text("Add").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Palette.mint)
                }
                .background(Palette.surface, in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Palette.mint.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a moment")
        .accessibilityIdentifier("profile.addVideo")
    }
}

