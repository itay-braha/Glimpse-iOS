import SwiftUI

/// The 20-connection meter. Mint while there's room, pink when the next match
/// will trigger an auto-boot.
struct CapacityRing: View {
    let active: Int
    let cap: Int
    var diameter: CGFloat = 44
    var lineWidth: CGFloat = 4

    private var progress: Double { cap == 0 ? 0 : min(Double(active) / Double(cap), 1) }
    private var tint: Color {
        if active >= cap { return Palette.pink }
        if active >= cap - 2 { return Palette.amber }
        return Palette.mint
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.textPrimary.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: progress)
            Text("\(active)")
                .font(.system(size: diameter * 0.34, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(active) of \(cap) connections")
    }
}

/// Compact pill used over the feed.
struct CapacityPill: View {
    let active: Int
    let cap: Int

    var body: some View {
        HStack(spacing: 8) {
            CapacityRing(active: active, cap: cap, diameter: 26, lineWidth: 3)
            Text("of \(cap)")
                .font(.glimpseCaption)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: .capsule)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 24) {
        CapacityRing(active: 9, cap: 15)
        CapacityRing(active: 14, cap: 15)
        CapacityPill(active: 15, cap: 15)
    }
    .padding()
    .background(Palette.midnight)
}
