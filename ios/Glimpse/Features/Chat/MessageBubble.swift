import SwiftUI
import UIKit

/// One message, with everything a modern chat expects:
///   * swipe right to reply (the quote shows above the reply);
///   * double-tap for ❤️; long-press for the reaction palette, Reply, Copy, Unsend;
///   * reaction chips under the bubble (tap yours to remove it);
///   * unsent messages read "Message unsent".
struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let showsTail: Bool
    /// The message this one replies to (if it's still loaded).
    var quoted: ChatMessage?
    var quotedAuthor: String = ""
    /// userID → emoji on this message.
    var reactions: [UUID: String] = [:]
    var myID: UUID?
    var canUnsend = false
    var onReact: (String) -> Void = { _ in }
    var onReply: () -> Void = {}
    var onUnsend: () -> Void = {}
    var onTapQuote: () -> Void = {}

    @State private var dragX: CGFloat = 0
    @State private var replyTrigger = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let replyThreshold: CGFloat = 64

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if isMine { Spacer(minLength: 56) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if let quoted {
                    quote(quoted)
                }
                bubble
                    .overlay(alignment: isMine ? .bottomLeading : .bottomTrailing) {
                        reactionChips
                            .offset(x: isMine ? -10 : 10, y: 14)
                    }
            }
            .padding(.bottom, reactions.isEmpty ? 0 : 16)
            if !isMine { Spacer(minLength: 56) }
        }
        .overlay(alignment: .leading) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.callout.weight(.bold))
                .foregroundStyle(Palette.mint)
                .opacity(Double(min(dragX / Self.replyThreshold, 1)))
                .scaleEffect(dragX >= Self.replyThreshold ? 1.15 : 0.85)
                .padding(.leading, 4)
                .accessibilityHidden(true)
        }
        .offset(x: dragX)
        .simultaneousGesture(replySwipe)
        .sensoryFeedback(.impact(weight: .light), trigger: replyTrigger)
        .padding(.bottom, showsTail ? 6 : 0)
    }

    private var bubble: some View {
        Text(message.isUnsent ? "Message unsent" : message.body)
            .font(message.isUnsent ? .glimpseBody.italic() : .glimpseBody)
            .foregroundStyle(message.isUnsent ? Palette.textTertiary : (isMine ? Palette.onMint : Palette.textPrimary))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(background, in: shape)
            .overlay {
                if message.isUnsent {
                    shape.strokeBorder(Palette.stroke, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .contentShape(shape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityIdentifier(isMine ? "bubble.mine" : "bubble.incoming")
            .accessibilityAction(named: "Reply", onReply)
            .accessibilityAction(named: "React with heart") { onReact("❤️") }
            .onTapGesture(count: 2) {
                guard !message.isUnsent else { return }
                onReact("❤️")
            }
            .contextMenu {
                if !message.isUnsent {
                    ControlGroup {
                        ForEach(MessageReaction.palette, id: \.self) { emoji in
                            Button { onReact(emoji) } label: { Text(emoji) }
                        }
                    }
                    .controlGroupStyle(.palette)
                    Button("Reply", systemImage: "arrowshape.turn.up.left", action: onReply)
                    Button("Copy", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = message.body
                    }
                    if canUnsend {
                        Button("Unsend", systemImage: "arrow.uturn.backward", role: .destructive, action: onUnsend)
                    }
                }
            }
    }

    private var background: Color {
        if message.isUnsent { return .clear }
        return isMine ? Palette.mint : Palette.surfaceRaised
    }

    private func quote(_ quoted: ChatMessage) -> some View {
        Button(action: onTapQuote) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(Palette.violet)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(quotedAuthor)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.violet)
                    Text(quoted.isUnsent ? "Message unsent" : quoted.body)
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.surface, in: .rect(cornerRadius: 12))
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Replying to \(quotedAuthor): \(quoted.body)")
    }

    @ViewBuilder
    private var reactionChips: some View {
        if !reactions.isEmpty {
            HStack(spacing: 2) {
                ForEach(chipOrder, id: \.self) { emoji in
                    let mine = reactions[myID ?? UUID()] == emoji
                    Button {
                        if mine { onReact(emoji) } // tapping your own removes it
                    } label: {
                        HStack(spacing: 2) {
                            Text(emoji).font(.caption)
                            let count = reactions.values.filter { $0 == emoji }.count
                            if count > 1 {
                                Text("\(count)").font(.caption2.weight(.bold)).foregroundStyle(Palette.textSecondary)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Palette.surfaceRaised, in: .capsule)
                        .overlay(Capsule().strokeBorder(mine ? Palette.mint : Palette.midnight, lineWidth: mine ? 1.5 : 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .accessibilityIdentifier("bubble.reactions")
        }
    }

    private var chipOrder: [String] {
        MessageReaction.palette.filter { reactions.values.contains($0) }
    }

    private var replySwipe: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard !message.isUnsent, value.translation.width > 0,
                      abs(value.translation.width) > abs(value.translation.height) * 1.3 else { return }
                let pulled = min(value.translation.width, 90)
                if pulled >= Self.replyThreshold && dragX < Self.replyThreshold { replyTrigger += 1 }
                dragX = pulled
            }
            .onEnded { _ in
                if dragX >= Self.replyThreshold { onReply() }
                withAnimation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.35)) { dragX = 0 }
            }
    }

    private var accessibilityText: String {
        var text = "\(isMine ? "You" : "Them"): \(message.isUnsent ? "Message unsent" : message.body)"
        if !reactions.isEmpty {
            text += ". Reactions: " + chipOrder.joined(separator: " ")
        }
        return text
    }

    private var shape: UnevenRoundedRectangle {
        let big: CGFloat = 20
        let small: CGFloat = showsTail ? 6 : 20
        return UnevenRoundedRectangle(
            topLeadingRadius: big,
            bottomLeadingRadius: isMine ? big : small,
            bottomTrailingRadius: isMine ? small : big,
            topTrailingRadius: big
        )
    }
}
