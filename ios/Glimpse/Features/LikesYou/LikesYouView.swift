import SwiftUI

/// "Liked you": free for everyone. Every admirer is shown and can be answered
/// straight from here.
struct LikesYouView: View {
    @Environment(AppModel.self) private var app
    @State private var model = LikesYouModel()
    @State private var previewing: FeedProfile?
    @State private var reporting: FeedProfile?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if model.likes.items.isEmpty && model.hasLoaded {
                    ContentUnavailableView(
                        "No new admirers yet",
                        systemImage: "heart.circle",
                        description: Text("Fresh moments get noticed. Keep your profile current.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(model.likes.items) { like in
                            if let profile = like.profile {
                                RevealedLikeCard(profile: profile, thumbnailURL: thumbnail(for: profile)) {
                                    previewing = profile
                                }
                                .contextMenu {
                                    Button("Like back", systemImage: "heart.fill") {
                                        Task {
                                            await model.likeBack(profile, using: app.backend)
                                            app.matchesDidChange()
                                        }
                                    }
                                    Button("Watch their clips", systemImage: "play.rectangle.fill") { previewing = profile }
                                    Button("Pass", systemImage: "xmark") {
                                        Task { await model.pass(profile, using: app.backend) }
                                    }
                                    Divider()
                                    Button("Report or block", systemImage: "flag", role: .destructive) { reporting = profile }
                                }
                            }
                        }
                    }
                }

                if let error = model.errorMessage {
                    ErrorText(error)
                }
            }
            .padding(16)
        }
        .background(Palette.midnight)
        .navigationTitle("Liked you")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.load(using: app.backend)
            app.track("likes_you_viewed", ["total": "\(model.likes.total)"])
        }
        .sheet(item: $previewing) { profile in
            AdmirerPreview(
                profile: profile,
                playableURLs: model.mediaURLs,
                onLike: {
                    previewing = nil
                    Task {
                        await model.likeBack(profile, using: app.backend)
                        app.matchesDidChange()
                    }
                },
                onPass: {
                    previewing = nil
                    Task { await model.pass(profile, using: app.backend) }
                }
            )
        }
        .sheet(item: $reporting) { profile in
            ReportSheet(
                name: profile.displayName,
                onSubmit: { reason, details in
                    try await app.backend.report(userID: profile.id, reason: reason, details: details, matchID: nil)
                },
                onDone: { Task { await model.load(using: app.backend) } }
            )
        }
        .fullScreenCover(item: $model.celebration) { celebration in
            MatchCelebrationView(
                celebration: celebration,
                myName: app.profile?.displayName ?? "You",
                onMessage: {
                    model.celebration = nil
                    app.openChat(celebration.match)
                },
                onDismiss: { model.celebration = nil }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.likes.total == 1 ? String(localized: "1 person wants to see more") : String(localized: "\(model.likes.total) people want to see more"))
                .font(.glimpseTitle2)
            Text("Liking someone back is always free, and it's an instant match.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)

        }
    }

    private func thumbnail(for profile: FeedProfile) -> URL? {
        profile.videos.first?.thumbnailPath.flatMap { model.mediaURLs[$0] }
    }
}

private struct RevealedLikeCard: View {
    let profile: FeedProfile
    let thumbnailURL: URL?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Palette.seededGradient(profile.displayName)
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    if let thumbnailURL {
                        AsyncImage(url: thumbnailURL) { $0.image?.resizable().scaledToFill() }
                    } else {
                        Text(String(profile.displayName.prefix(1)))
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.25))
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 4) {
                        Text("\(profile.displayName), \(profile.age)")
                            .font(.glimpseHeadline)
                        if profile.isVerified == true { VerifiedBadge(size: 16) }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                }
                .clipShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(profile.displayName), \(profile.age). Liked you.")
    }
}

/// Full-screen look at an admirer with like-back and pass.
private struct AdmirerPreview: View {
    let profile: FeedProfile
    let playableURLs: [String: URL]
    let onLike: () -> Void
    let onPass: () -> Void

    var body: some View {
        GeometryReader { proxy in
            FeedCardView(
                profile: profile,
                playableURLs: playableURLs,
                isActive: true,
                isLiked: false,
                insets: proxy.safeAreaInsets,
                onLike: onLike,
                onPass: onPass,
                onReport: onPass
            )
            .ignoresSafeArea()
        }
        .presentationDragIndicator(.visible)
    }
}
