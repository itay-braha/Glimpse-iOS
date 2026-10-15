import SwiftUI

struct MyProfileView: View {
    @Environment(AppModel.self) private var app
    @State private var model = ProfileModel()
    @State private var showAddOptions = false
    @State private var showRecorder = false
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
                            showAddOptions = true
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
                                        if video.id != model.videos.first?.id {
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
                                AddVideoTile(isBusy: model.isImporting) { showAddOptions = true }
                            }
                        }
                        Text("Every moment shows when it was added. Clips older than 90 days get a nudge to rotate. Long-press a clip to make it your cover.")
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
        }
        .confirmationDialog("Add a moment", isPresented: $showAddOptions, titleVisibility: .visible) {
            Button("Record a 15s clip") { showRecorder = true }
            Button("Import from Instagram") {
                Task { await model.importInstagram(using: app.backend, config: app.config) }
            }
        } message: {
            Text("TikTok import is coming soon.")
        }
        .fullScreenCover(isPresented: $showRecorder) {
            RecorderView { video in
                if let video {
                    Task { await model.added(video, using: app.backend) }
                }
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
                Text(count == 1 ? "1 moment is over 90 days old" : "\(count) moments are over 90 days old")
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

    private var isStale: Bool { Recency.isStale(video.importedAt) }

    var body: some View {
        Color.clear
            .aspectRatio(9 / 16, contentMode: .fit)
            .background {
                ZStack {
                    Palette.seededGradient(video.id.uuidString)
                    if let thumbnailURL {
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
                if isStale {
                    Text("Rotate")
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
                    .strokeBorder(isStale ? Palette.pink : Palette.stroke, lineWidth: isStale ? 2 : 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(video.source.displayName) moment, \(Recency.label(video.importedAt))\(isStale ? ", needs rotating" : "")")
    }
}

private struct AddVideoTile: View {
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear
                .aspectRatio(9 / 16, contentMode: .fit)
                .overlay {
                    if isBusy {
                        ProgressView()
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.title2.weight(.bold))
                            Text("Add").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Palette.mint)
                    }
                }
                .background(Palette.surface, in: .rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Palette.mint.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel("Add a moment")
    }
}

