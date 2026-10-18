import Foundation

/// Seed content for demo mode. Clips are freely licensed test videos
/// (Creative Commons films via test-videos.co.uk, CC0 sample from MDN).
enum DemoData {
    static let meID = UUID(uuidString: "00000000-0000-4000-8000-000000000000")!

    /// What a demo build sends when the simulator has no camera or microphone.
    static func chatSample(_ kind: MessageKind) -> URL? {
        switch kind {
        case .voice: URL(string: "https://interactive-examples.mdn.mozilla.net/media/cc0-audio/t-rex-roar.mp3")
        case .video: URL(string: clipURLs[2])
        case .text: nil
        }
    }

    static let clipURLs = [
        "https://test-videos.co.uk/vids/jellyfish/mp4/h264/720/Jellyfish_720_10s_1MB.mp4",
        "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4",
        "https://test-videos.co.uk/vids/sintel/mp4/h264/720/Sintel_720_10s_1MB.mp4",
        "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4",
    ]

    static func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012lx", n))!
    }

    static func daysAgo(_ days: Double, from now: Date = .now) -> Date {
        now.addingTimeInterval(-days * 86_400)
    }

    static func video(_ n: Int, source: VideoSource, importedDaysAgo: Double, now: Date = .now) -> ProfileVideo {
        ProfileVideo(
            id: id(10_000 + n),
            source: source,
            storagePath: clipURLs[n % clipURLs.count],
            thumbnailPath: nil,
            durationSeconds: source == .native ? 15 : 14,
            capturedAt: daysAgo(importedDaysAgo + 9, from: now),
            importedAt: daysAgo(importedDaysAgo, from: now)
        )
    }

    /// A linked public post. Demo builds render a stand-in instead of calling the platform.
    static func embed(_ n: Int, platform: EmbedLink.Platform, importedDaysAgo: Double, now: Date = .now) -> ProfileVideo {
        let url = switch platform {
        case .instagram: "https://www.instagram.com/reel/GlimpseDemo\(n)/"
        case .tiktok: "https://www.tiktok.com/@glimpse.demo/video/73000000000000\(n)"
        }
        return ProfileVideo(
            id: id(10_000 + n),
            source: platform.source,
            videoType: .embed,
            storagePath: nil,
            embedURL: URL(string: url),
            durationSeconds: nil,
            capturedAt: daysAgo(importedDaysAgo, from: now),
            importedAt: daysAgo(importedDaysAgo, from: now)
        )
    }

    static func myProfile() -> UserProfile {
        UserProfile(
            id: meID,
            displayName: "Itay",
            birthdate: "1998-05-14",
            gender: .man,
            interestedIn: [.woman],
            bio: "Building things by day, chasing sunsets on a bike by night.",
            city: "Tel Aviv",
            ageMin: 21,
            ageMax: 32,
            isOnboarded: true,
            maxDistanceKm: 50,
            isVerified: true,
            verificationStatus: "verified"
        )
    }

    static func myVideos(now: Date = .now) -> [ProfileVideo] {
        [
            video(1, source: .upload, importedDaysAgo: 3, now: now),
            video(2, source: .native, importedDaysAgo: 12, now: now),
            video(4, source: .upload, importedDaysAgo: 380, now: now),
            embed(90, platform: .instagram, importedDaysAgo: 20, now: now),
        ]
    }

    private static let people: [(String, Int, String, String)] = [
        ("Maya", 26, "Tel Aviv", "Sunrise swims, too many houseplants, will judge your coffee order."),
        ("Noa", 24, "Jaffa", "Ceramics studio regular. Looking for someone to get lost in flea markets with."),
        ("Shira", 27, "Haifa", "Climber. Bad at karaoke, great at hype."),
        ("Yael", 25, "Tel Aviv", "Street food tour guide in another life."),
        ("Tamar", 28, "Jerusalem", "Film photography + midnight bakery runs."),
        ("Romi", 23, "Herzliya", "Dancing badly at every wedding. Proudly."),
        ("Lior", 29, "Tel Aviv", "Product designer, amateur DJ, professional dog-petter."),
        ("Ella", 26, "Ramat Gan", "Half marathons, full pizzas."),
    ]

    static func feed(now: Date = .now) -> [FeedProfile] {
        people.enumerated().map { index, person in
            FeedProfile(
                id: id(100 + index),
                displayName: person.0,
                age: person.1,
                city: person.2,
                bio: person.3,
                isVerified: index.isMultiple(of: 3),
                distanceKm: 2 + (index * 7) % 23,
                videos: [
                    video(index * 2, source: index.isMultiple(of: 3) ? .native : .upload, importedDaysAgo: Double(index % 5) + 1, now: now),
                    video(index * 2 + 1, source: index.isMultiple(of: 2) ? .upload : .native, importedDaysAgo: Double(index % 4) * 6 + 9, now: now),
                ] + (index == 0 ? [embed(91, platform: .tiktok, importedDaysAgo: 6, now: now)] : []),
                // Like the server: widened suggestions come last, and say so.
                discoveryNote: index == people.count - 1 ? .widerDistance
                    : index == people.count - 2 ? .secondLook : nil
            )
        }
    }

    private static let admirerPeople: [(String, Int, String, String)] = [
        ("Adi", 25, "Tel Aviv", "Runs on iced coffee and spontaneous beach days."),
        ("Shani", 27, "Ramat Gan", "Pilates instructor. Will absolutely make you stretch."),
        ("Neta", 24, "Jaffa", "Vintage hunter, sourdough apologist."),
        ("Liel", 28, "Herzliya", "Sailing on weekends, spreadsheets on weekdays."),
        ("Dana R.", 26, "Tel Aviv", "Board games, bad puns, good wine."),
    ]

    /// People who liked "me" but aren't in the feed yet (the "Liked you" screen).
    static func admirers(now: Date = .now) -> [FeedProfile] {
        admirerPeople.enumerated().map { index, person in
            FeedProfile(
                id: id(300 + index),
                displayName: person.0,
                age: person.1,
                city: person.2,
                bio: person.3,
                isVerified: index.isMultiple(of: 2),
                distanceKm: 1 + (index * 5) % 17,
                videos: [video(20 + index, source: .upload, importedDaysAgo: Double(index) + 2, now: now)]
            )
        }
    }

    static func missedConnections(now: Date = .now) -> [MissedConnection] {
        [
            MissedConnection(
                matchID: id(1_900),
                userID: id(1_901),
                displayName: "Shir",
                age: 25,
                thumbnailPath: nil,
                endedAt: daysAgo(2, from: now),
                secondChanceStatus: nil
            ),
        ]
    }

    /// Someone asking to reconnect after "my" circle released them.
    static func secondChance(now: Date = .now) -> SecondChance {
        SecondChance(
            id: id(1_950),
            createdAt: daysAgo(0.2, from: now),
            profile: FeedProfile(
                id: id(1_951),
                displayName: "Noy",
                age: 26,
                city: "Tel Aviv",
                bio: "Still thinking about that falafel debate.",
                isVerified: true,
                distanceKm: 3,
                videos: [video(30, source: .native, importedDaysAgo: 4, now: now)]
            )
        )
    }

    static func notices(now: Date = .now) -> [AppNotification] {
        [
            AppNotification(
                id: id(40_000),
                kind: .connectionEnded,
                title: "A connection ended",
                body: "Your connection with Bar has ended.",
                data: nil,
                createdAt: daysAgo(0.3, from: now),
                readAt: nil
            ),
        ]
    }

    /// Every other feed profile has already liked "me", so liking them matches.
    static func likedMe() -> Set<UUID> {
        Set((0..<people.count).filter { $0.isMultiple(of: 2) }.map { id(100 + $0) })
    }

    private static let matchNames = [
        "Dana", "Hila", "Gal", "Adi", "Neta", "Mia", "Chen", "Talia", "Keren", "Avital",
        "Libby", "Ori", "Inbar", "Sivan", "Michal", "Rotem", "Daniella", "Hadar", "Yuval", "Stav",
    ]

    private static let lastLines = [
        "Okay but which hummus place is actually the best?",
        "Haha that's exactly what I was thinking",
        "Saturday works for me!",
        "You have to send me that playlist",
        "I've never been, take me?",
        "lol no way",
        "Wait, you climb too?",
        "Good morning ☀️",
    ]

    static func matches(now: Date = .now) -> [MatchSummary] {
        matchNames.enumerated().map { index, name in
            // Dana (index 0) has gone quiet: the auto-boot engine's next pick.
            let quietDays: Double = index == 0 ? 19 : Double(index % 7) * 0.6 + Double(index) * 0.08
            let count = index == 0 ? 1 : 6 + (index * 5) % 37
            return MatchSummary(
                matchID: id(1_000 + index),
                otherUserID: id(2_000 + index),
                displayName: name,
                age: 22 + index % 9,
                city: ["Tel Aviv", "Haifa", "Jerusalem", "Jaffa"][index % 4],
                thumbnailPath: nil,
                createdAt: daysAgo(quietDays + 4 + Double(index % 3), from: now),
                lastMessageAt: daysAgo(quietDays, from: now),
                messageCount: count,
                lastMessageBody: lastLines[index % lastLines.count],
                lastMessageMine: index.isMultiple(of: 3),
                unreadCount: index % 4 == 1 ? (index % 3) + 1 : 0,
                bootRank: 0
            )
        }
    }

    static func conversation(for match: MatchSummary, now: Date = .now) -> [ChatMessage] {
        let lines: [(Bool, String)] = [
            (false, "Your clip from the beach cleanup was the best thing on my feed today"),
            (true, "Haha thank you! It was 6am and I was barely awake"),
            (false, "Respect. I can't get up before 9 without three coffees"),
            (true, "Then we're doing a sunset thing instead"),
            (false, match.lastMessageBody ?? "Deal 😄"),
        ]
        let start = match.lastActivity.addingTimeInterval(-Double(lines.count) * 420)
        var conversation = lines.enumerated().map { index, line in
            ChatMessage(
                id: UUID(),
                matchID: match.matchID,
                senderID: line.0 ? meID : match.otherUserID,
                body: line.1,
                createdAt: start.addingTimeInterval(Double(index) * 420),
                readAt: line.0 ? start.addingTimeInterval(Double(index) * 420 + 60) : nil
            )
        }
        // "Then we're doing a sunset thing instead" answers "Respect. I can't get up before 9…"
        conversation[3].replyTo = conversation[2].id
        return conversation
    }

    static let replies = [
        "Haha okay I like where this is going",
        "Wait, tell me more 👀",
        "That's actually so funny",
        "I'm free Thursday evening!",
        "Okay you win this round",
    ]
}
