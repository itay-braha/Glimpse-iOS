import SwiftUI

/// Asked once, before iOS's own permission prompt: what should buzz? People who
/// pick something get the system prompt next; "Not now" asks nothing, and the
/// choice can be changed any time in Settings.
struct AlertChoiceSheet: View {
    let onChoose: (PushScope?) -> Void

    @State private var selection: PushScope = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 40))
                .foregroundStyle(Palette.brandGradient)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 8) {
                Text("Don't miss a Glimpse")
                    .font(.glimpseTitle)
                Text("Choose what we tell you about. You can change it any time in Settings.")
                    .font(.glimpseBody)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                ForEach([PushScope.all, .messages]) { scope in
                    ChoiceRow(scope: scope, isSelected: selection == scope) { selection = scope }
                }
            }

            Spacer(minLength: 0)

            Button("Turn on alerts") { onChoose(selection) }
                .buttonStyle(.glimpse)
                .accessibilityIdentifier("alerts.turnOn")
            Button("Not now") { onChoose(nil) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("alerts.notNow")
        }
        .padding(24)
        .background(Palette.midnight)
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
}

private struct ChoiceRow: View {
    let scope: PushScope
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: scope == .all ? "sparkles" : "bubble.left.and.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(scope == .all ? Palette.pink : Palette.mint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(scope.title).font(.glimpseHeadline).foregroundStyle(Palette.textPrimary)
                        if scope == .all {
                            Text("Recommended")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(Palette.onMint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Palette.mint, in: .capsule)
                        }
                    }
                    Text(scope.detail)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Palette.mint : Palette.textTertiary)
            }
            .padding(16)
            .background(Palette.surface, in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? Palette.mint : Palette.stroke, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("alerts.\(scope.rawValue)")
    }
}
