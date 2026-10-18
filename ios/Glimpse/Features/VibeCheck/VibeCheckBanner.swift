import SwiftUI

/// The Vibe Check entry point at the top of a chat. What it shows depends on
/// who holds the key and where the check is in its lifecycle.
struct VibeCheckBanner: View {
    let state: VibeCheckState
    let name: String
    let onInvite: () -> Void
    let onGreenLight: () -> Void
    let onNotYet: () -> Void
    let onSuggest: () -> Void
    let onAnswer: (Bool) -> Void
    let onJoin: () -> Void

    var body: some View {
        Group {
            if state.vibeVerified {
                pill(symbol: "checkmark.seal.fill", text: "Vibe Verified · protected from auto-release", tint: Palette.mint)
            } else if state.status == .scheduled {
                scheduled
            } else if state.showNudge {
                nudge
            } else if !state.iHoldKey && state.status == .femaleUnlocked && state.unlockedByOther == true {
                card(
                    title: "\(name) unlocked the 3-Minute Vibe Check",
                    detail: "Suggest a time to chat.",
                    primary: ("Suggest a time", onSuggest)
                )
            } else {
                EmptyView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    private var nudge: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("✨ Conversation is flowing. Ready for a Vibe Check?")
                .font(.glimpseHeadline)
            Text("Test the chemistry with a 3-minute video chat before planning to meet.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 8) {
                Button("Invite now", action: onInvite)
                    .buttonStyle(GlimpseButtonStyle(kind: .primary))
                Button("Green light", action: onGreenLight)
                    .buttonStyle(GlimpseButtonStyle(kind: .secondary))
            }
            PrivateCallNote()
            Button("Not yet", action: onNotYet)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .modifier(CardStyle())
    }

    @ViewBuilder
    private var scheduled: some View {
        let time = state.scheduledAt.map { $0.formatted(date: .omitted, time: .shortened) } ?? ""
        let day = state.scheduledAt.map { Calendar.current.isDateInToday($0) ? "Today" : $0.formatted(.dateTime.weekday(.wide)) } ?? ""
        if state.canJoin {
            card(title: "Your Vibe Check is open", detail: "Join the lobby when you're ready. It lasts exactly 3 minutes.",
                 primary: ("Join Vibe Check", onJoin))
        } else if state.awaitingMyAnswer {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(name) suggested a Vibe Check · \(day) \(time)")
                    .font(.glimpseHeadline)
                HStack(spacing: 8) {
                    Button("Accept") { onAnswer(true) }
                        .buttonStyle(GlimpseButtonStyle(kind: .primary))
                    Button("Can't make it") { onAnswer(false) }
                        .buttonStyle(GlimpseButtonStyle(kind: .secondary))
                }
                PrivateCallNote()
            }
            .modifier(CardStyle())
        } else if state.confirmed {
            pill(symbol: "calendar.badge.clock", text: "Vibe Check · \(day) \(time)", tint: Palette.violet)
        } else {
            pill(symbol: "hourglass", text: "Waiting for \(name) to confirm \(day) \(time)", tint: Palette.textSecondary)
        }
    }

    private func card(title: LocalizedStringKey, detail: LocalizedStringKey, primary: (LocalizedStringKey, () -> Void)) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.glimpseHeadline)
            Text(detail).font(.subheadline).foregroundStyle(Palette.textSecondary)
            Button(primary.0, action: primary.1)
                .buttonStyle(GlimpseButtonStyle(kind: .primary))
            PrivateCallNote()
        }
        .modifier(CardStyle())
    }

    private func pill(symbol: String, text: LocalizedStringKey, tint: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Palette.surface, in: .capsule)
    }
}

/// The quiet promise under every Vibe Check invitation.
private struct PrivateCallNote: View {
    var body: some View {
        Label {
            Text("Private by design. A Vibe Check can't be screenshotted or recorded by either of you.")
        } icon: {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Palette.violet)
        }
        .font(.caption)
        .italic()
        .foregroundStyle(Palette.textTertiary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("vibe.privateNote")
    }
}

private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.violet.opacity(0.45)))
    }
}
