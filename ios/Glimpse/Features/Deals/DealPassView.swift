import SwiftUI

/// The live pass shown at the counter. Staff need nothing: the moving colours, the
/// ticking clock and today's code show it's live (not a screenshot), and they tap Redeem
/// on the member's phone.
struct DealPassView: View {
    let deal: Deal
    let pass: DealPass
    let onRedeem: () async -> Void
    let onClose: () -> Void

    @State private var confirmRedeem = false
    @State private var isRedeeming = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 0) {
                card(now: context.date)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                Spacer(minLength: 16)
                staffArea(now: context.date)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .confirmationDialog("Redeem this deal now?", isPresented: $confirmRedeem, titleVisibility: .visible) {
            Button("Redeem") {
                isRedeeming = true
                Task {
                    await onRedeem()
                    isRedeeming = false
                }
            }
            .accessibilityIdentifier("deal.confirmRedeem")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only staff at \(deal.place) should tap this. It can't be undone.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deal.pass")
    }

    private func card(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Wordmark(size: 22)
                Spacer()
                Text(pass.code)
                    .font(.system(.headline, design: .monospaced).weight(.heavy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.25), in: .capsule)
                    .accessibilityLabel("Today's code \(pass.code)")
            }
            Spacer(minLength: 8)
            Text(deal.place)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            Text(deal.title)
                .font(.title2.weight(.bold))
            if let details = deal.details {
                Text(details).font(.subheadline).opacity(0.9)
            }
            Spacer(minLength: 8)
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("For \(pass.name)").font(.headline)
                    Text(now.formatted(.dateTime.hour().minute().second()))
                        .font(.system(.title3, design: .monospaced).weight(.semibold))
                        .contentTransition(.numericText())
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle)
                    .symbolEffect(.pulse, options: .repeating)
            }
        }
        .foregroundStyle(Palette.onMint)
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 360, alignment: .leading)
        .background(livingGradient(now: now), in: .rect(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.35), lineWidth: 1))
        .shadow(color: Palette.mint.opacity(0.35), radius: 24, y: 8)
    }

    /// Slowly shifting colours, so a still picture of the pass looks different.
    private func livingGradient(now: Date) -> LinearGradient {
        let phase = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 8) / 8
        return LinearGradient(
            colors: [Palette.mint, Color(hex: 0x7AF0FF), Palette.mint.opacity(0.85)],
            startPoint: UnitPoint(x: phase, y: 0),
            endPoint: UnitPoint(x: 1 - phase, y: 1)
        )
    }

    private func staffArea(now: Date) -> some View {
        let left = max(0, Int(pass.expiresAt.timeIntervalSince(now)))
        return VStack(spacing: 10) {
            if left > 0 {
                Text("Valid for \(left / 60):\(String(format: "%02d", left % 60))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Palette.textTertiary)
            }
            Button {
                confirmRedeem = true
            } label: {
                if isRedeeming {
                    ProgressView().tint(Palette.onMint)
                } else {
                    Label("Staff: tap to redeem", systemImage: "hand.tap.fill")
                }
            }
            .buttonStyle(GlimpseButtonStyle(kind: .primary))
            .disabled(isRedeeming || left == 0)
            .accessibilityIdentifier("deal.redeem")
            if let terms = deal.terms {
                Text(terms)
                    .font(.caption)
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)
            }
            Button("Not now", action: onClose)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
        }
    }
}
