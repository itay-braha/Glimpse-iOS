import SwiftUI

/// Pick a height in cm, or choose not to show it. Picking a height shows it again.
struct HeightChooser: View {
    @Binding var heightCm: Int?
    @Binding var hidesHeight: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                Picker("Height", selection: Binding(
                    get: { heightCm ?? HeightSetting.pickerStart },
                    set: { heightCm = $0; hidesHeight = false }
                )) {
                    ForEach(Array(HeightSetting.range.reversed()), id: \.self) { cm in
                        Text(HeightSetting.label(cm)).tag(cm)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "ruler")
                        .foregroundStyle(Palette.textTertiary)
                    Text(heightCm.map(HeightSetting.label) ?? String(localized: "Choose your height"))
                        .foregroundStyle(heightCm == nil ? Palette.textTertiary : Palette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.textTertiary)
                }
                .font(.glimpseHeadline)
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(Palette.surfaceRaised, in: .rect(cornerRadius: 16))
                .opacity(hidesHeight ? 0.5 : 1)
            }
            .accessibilityIdentifier("height.choose")

            SelectableChip(title: "Don't show my height", isSelected: hidesHeight) {
                hidesHeight.toggle()
            }
            .accessibilityIdentifier("height.hide")

            Text(hidesHeight
                ? String(localized: "It won't appear on your profile. You can add it any time.")
                : String(localized: "Shown on your profile while people watch your clips."))
                .font(.glimpseCaption)
                .foregroundStyle(Palette.textTertiary)
        }
    }
}
