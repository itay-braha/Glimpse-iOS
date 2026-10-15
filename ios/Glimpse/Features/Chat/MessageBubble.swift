import SwiftUI
import UIKit

struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let showsTail: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 56) }
            Text(message.body)
                .font(.glimpseBody)
                .foregroundStyle(isMine ? Palette.onMint : Palette.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isMine ? Palette.mint : Palette.surfaceRaised, in: shape)
                .contextMenu {
                    Button("Copy", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = message.body
                    }
                }
            if !isMine { Spacer(minLength: 56) }
        }
        .padding(.bottom, showsTail ? 6 : 0)
        .accessibilityLabel("\(isMine ? "You" : "Them"): \(message.body)")
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
