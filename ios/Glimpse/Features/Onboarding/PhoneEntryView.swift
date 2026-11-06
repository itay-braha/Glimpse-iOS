import SwiftUI

struct PhoneEntryView: View {
    @Environment(AppModel.self) private var app
    @Bindable var model: AuthFlowModel
    @FocusState private var focused: Bool
    /// Shown once someone types the trunk "0" the country code already covers.
    @State private var droppedLeadingZero = false

    var body: some View {
        OnboardingScaffold(
            title: "What's your number?",
            subtitle: "We'll text you a code. Glimpse only accepts real mobile numbers, so no VOIP or virtual numbers.",
            onBack: { model.step = .welcome }
        ) {
            CountryChip(selection: $model.dialCode)

            ZStack {
                // The real input: invisible, but it owns the keyboard, autofill and paste.
                TextField("Mobile number", text: $model.nationalNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .focused($focused)
                    .opacity(0.02)
                    .accessibilityLabel("Mobile number")

                PhoneSlots(digits: model.nationalNumber, groups: model.dialCode.groups, isFocused: focused)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
            .onTapGesture { focused = true }

            if droppedLeadingZero {
                Label("No need for the leading 0, the country code covers it.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(Palette.textSecondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let error = model.errorMessage {
                ErrorText(error)
            }

            if app.isDemo {
                DemoHint("Demo mode: any number works, the code is 123456.")
            }
        } footer: {
            Button {
                Task { await model.sendCode(using: app.backend) }
            } label: {
                if model.isWorking {
                    ProgressView().tint(Palette.onMint)
                } else {
                    Text("Send code")
                }
            }
            .buttonStyle(.glimpse)
            .disabled(!model.canSendCode)
        }
        .onAppear { focused = true }
        .onChange(of: model.nationalNumber) { _, typed in
            let clean = PhoneNumber.nationalDigits(typed, dialCode: model.dialCode)
            if typed.filter(\.isNumber).hasPrefix("0") && !typed.hasPrefix("00") {
                withAnimation(.snappy) { droppedLeadingZero = true }
            }
            if clean != typed { model.nationalNumber = clean }
        }
        .onChange(of: model.dialCode) { _, dial in
            model.nationalNumber = PhoneNumber.nationalDigits(model.nationalNumber, dialCode: dial)
        }
        .sensoryFeedback(.selection, trigger: model.nationalNumber.count)
    }
}

/// Flag, dial code and country name; opens the country list.
private struct CountryChip: View {
    @Binding var selection: DialCode

    var body: some View {
        Menu {
            Picker("Country", selection: $selection) {
                ForEach(DialCode.all) { dial in
                    Text(verbatim: "\(dial.flag)  \(dial.countryName)  +\(dial.code)").tag(dial)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selection.flag)
                    .font(.title2)
                Text(verbatim: "+\(selection.code)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .environment(\.layoutDirection, .leftToRight)
                Text(selection.countryName)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Palette.surfaceRaised, in: .capsule)
            .overlay(Capsule().strokeBorder(Palette.stroke))
        }
        .accessibilityLabel("Country: \(selection.countryName), +\(selection.code)")
    }
}

/// One slot per digit, grouped the way the country writes its numbers.
/// Always left to right: phone numbers read that way in Hebrew too.
private struct PhoneSlots: View {
    let digits: String
    let groups: [Int]
    let isFocused: Bool

    private var total: Int { groups.reduce(0, +) }

    var body: some View {
        let typed = Array(digits)
        HStack(spacing: total > 10 ? 7 : 10) {
            ForEach(Array(groups.enumerated()), id: \.offset) { groupIndex, size in
                let start = groups.prefix(groupIndex).reduce(0, +)
                HStack(spacing: total > 10 ? 3 : 4) {
                    ForEach(start..<(start + size), id: \.self) { index in
                        DigitSlot(
                            digit: index < typed.count ? typed[index] : nil,
                            isActive: isFocused && index == typed.count,
                            height: 54
                        )
                    }
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .animation(.snappy, value: groups)
    }
}
