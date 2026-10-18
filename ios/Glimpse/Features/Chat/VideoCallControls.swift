import SwiftUI

/// Opens a video call screen (ringing out, or answering).
struct VideoCallLaunch: Identifiable, Hashable {
    let callID: UUID
    let recordingAgreed: Bool
    var id: UUID { callID }
}

/// "Dana is video calling": answer or decline, right in the chat.
struct IncomingCallCard: View {
    let name: String
    let onAnswer: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "video.fill")
                .font(.title3)
                .foregroundStyle(Palette.mint)
                .symbolEffect(.pulse)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name) is video calling").font(.glimpseHeadline)
                Text("Up to 15 minutes").font(.caption).foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Button("Decline", systemImage: "phone.down.fill", action: onDecline)
                .labelStyle(.iconOnly)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.red, in: .circle)
                .accessibilityIdentifier("call.decline")
            Button("Answer", systemImage: "video.fill", action: onAnswer)
                .labelStyle(.iconOnly)
                .foregroundStyle(Palette.onMint)
                .frame(width: 44, height: 44)
                .background(Palette.mint, in: .circle)
                .accessibilityIdentifier("call.answer")
        }
        .padding(14)
        .background(Palette.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.mint.opacity(0.5)))
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("call.incoming")
    }
}

/// Shown once ever, after a good Vibe Check, to someone who decides on video calls
/// but has them off. Points to Settings; never asks again.
struct VideoCallsTipCard: View {
    let name: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "video.badge.checkmark")
                .font(.title3)
                .foregroundStyle(Palette.violet)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("You and \(name) clicked ✨").font(.glimpseHeadline)
                Text("If you ever want longer video calls with people you've Vibe Verified, you can turn them on in Settings → Video calls. Off unless you choose it.")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(14)
        .background(Palette.surface, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("call.tip")
    }
}
