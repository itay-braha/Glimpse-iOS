import SwiftUI

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.glimpseHeadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundStyle(isSelected ? Palette.onMint : Palette.textPrimary)
                .background(isSelected ? Palette.mint : Palette.surfaceRaised, in: .capsule)
                .overlay(Capsule().strokeBorder(isSelected ? .clear : Palette.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}
