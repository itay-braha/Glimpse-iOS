import SwiftUI

/// "Glimpse is unlocking near you": the city waitlist with an invite button.
struct DensityGateView: View {
    let status: DensityStatus
    let onRefresh: () -> Void

    private var progress: Double {
        status.required == 0 ? 1 : min(Double(status.localMembers) / Double(status.required), 1)
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            LogoMark(size: 72)
            Text("Glimpse is unlocking near you soon")
                .font(.glimpseTitle2)
                .multilineTextAlignment(.center)
            Text("We open a city once enough people are here, so your feed is full from day one.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .tint(Palette.mint)
                Text("\(status.localMembers)/\(status.required) local members ready")
                    .font(.glimpseCaption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 24)
            ShareLink(
                item: "I'm on Glimpse: real people, real video, max 20 connections. Join me so it unlocks in our city!",
                subject: Text("Join me on Glimpse")
            ) {
                Label("Invite friends to unlock faster", systemImage: "person.2.fill")
            }
            .buttonStyle(.glimpse)
            Button("Check again", action: onRefresh)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
        }
        .padding(28)
    }
}

/// Shown when a free member has seen today's new profiles.
struct OutOfGlimpsesView: View {
    let resetsAt: Date?
    let isPlus: Bool
    let onConnections: () -> Void
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.brandGradient)
            Text("You've seen today's glimpses")
                .font(.glimpseTitle2)
            Group {
                if let resetsAt {
                    Text("Fresh profiles arrive \(resetsAt, format: .relative(presentation: .named)). Until then, the best move is a real conversation.")
                } else {
                    Text("Fresh profiles arrive tomorrow. Until then, the best move is a real conversation.")
                }
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.textSecondary)
            Button("Talk to your connections", action: onConnections)
                .buttonStyle(.glimpse)
            if !isPlus {
                Button("See more with Glimpse+", action: onUpgrade)
                    .buttonStyle(.glimpseSecondary)
            }
            Spacer()
        }
        .padding(32)
    }
}

/// Vacation mode is on.
struct PausedFeedView: View {
    let until: Date
    let onResume: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.amber)
            Text("You're on a break")
                .font(.glimpseTitle2)
            Text("Until \(until.formatted(date: .abbreviated, time: .omitted)) you're hidden from discovery, your matches see you're away, and nothing counts against you.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
            Button("Resume now", action: onResume)
                .buttonStyle(.glimpse)
            Spacer()
        }
        .padding(32)
    }
}

/// At 20/20, liking someone can release a connection. Make it a choice.
struct CapacityConfirmSheet: View {
    let candidateName: String
    let next: NextToBoot
    let canFreeze: Bool
    let onLikeAnyway: () -> Void
    let onFreezeThenLike: () -> Void
    let onChatFirst: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your circle is full")
                .font(.glimpseTitle2)
            Text("If you and \(candidateName) match, your quietest connection, **\(next.displayName)**, will be released to make room. Talk to them, protect them, or let them go.")
                .foregroundStyle(Palette.textSecondary)

            Button("Chat with \(next.displayName) first") { act(onChatFirst) }
                .buttonStyle(.glimpseSecondary)
            if canFreeze {
                Button("Freeze \(next.displayName), then like") { act(onFreezeThenLike) }
                    .buttonStyle(.glimpseSecondary)
            }
            Button("Like \(candidateName) anyway") { act(onLikeAnyway) }
                .buttonStyle(.glimpse)
        }
        .padding(24)
        .presentationDetents([.medium])
        .background(Palette.midnight)
    }

    private func act(_ action: () -> Void) {
        action()
        dismiss()
    }
}
