import SwiftUI

struct CodeEntryView: View {
    @Environment(AppModel.self) private var app
    @Bindable var model: AuthFlowModel
    @FocusState private var focused: Bool

    var body: some View {
        OnboardingScaffold(
            title: "Enter your code",
            subtitle: "Sent to \(model.e164 ?? "your phone").",
            onBack: { model.step = .phone }
        ) {
            ZStack {
                TextField("", text: $model.code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focused)
                    .opacity(0.02)
                    .accessibilityLabel("Six digit code")

                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { index in
                        CodeDigitBox(
                            digit: digit(at: index),
                            isActive: focused && index == min(model.code.count, 5)
                        )
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .contentShape(.rect)
            .onTapGesture { focused = true }

            if let error = model.errorMessage {
                ErrorText(error)
            }

            Button("Resend code") {
                Task { await model.sendCode(using: app.backend) }
            }
            .font(.glimpseHeadline)
            .foregroundStyle(Palette.mint)
            .disabled(model.isWorking)
        } footer: {
            Button {
                submit()
            } label: {
                if model.isWorking {
                    ProgressView().tint(Palette.onMint)
                } else {
                    Text("Verify")
                }
            }
            .buttonStyle(.glimpse)
            .disabled(model.code.count != 6 || model.isWorking)
        }
        .onAppear { focused = true }
        .onChange(of: model.code) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(6))
            if digits != newValue {
                model.code = digits
            } else if digits.count == 6 {
                submit()
            }
        }
    }

    private func digit(at index: Int) -> String {
        guard index < model.code.count else { return "" }
        return String(model.code[model.code.index(model.code.startIndex, offsetBy: index)])
    }

    private func submit() {
        Task {
            if await model.verify(using: app.backend) {
                await app.completeSignIn()
            }
        }
    }
}

private struct CodeDigitBox: View {
    let digit: String
    let isActive: Bool

    var body: some View {
        Text(digit)
            .font(.system(.title, design: .rounded, weight: .bold))
            .monospacedDigit()
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(Palette.surfaceRaised, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isActive ? Palette.mint : Palette.stroke, lineWidth: isActive ? 2 : 1)
            }
    }
}
