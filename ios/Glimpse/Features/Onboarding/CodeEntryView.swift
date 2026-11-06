import SwiftUI

struct CodeEntryView: View {
    @Environment(AppModel.self) private var app
    @Bindable var model: AuthFlowModel
    @FocusState private var focused: Bool
    @State private var verified = 0

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

                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        DigitSlot(
                            digit: digit(at: index),
                            isActive: focused && index == model.code.count,
                            height: 64
                        )
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .shake(trigger: model.failedAttempts)
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
        .sensoryFeedback(.selection, trigger: model.code.count)
        .sensoryFeedback(.error, trigger: model.failedAttempts)
        .sensoryFeedback(.success, trigger: verified)
        .onChange(of: model.code) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(6))
            if digits != newValue {
                model.code = digits
            } else if digits.count == 6 {
                submit()
            }
        }
    }

    private func digit(at index: Int) -> Character? {
        guard index < model.code.count else { return nil }
        return model.code[model.code.index(model.code.startIndex, offsetBy: index)]
    }

    private func submit() {
        Task {
            if await model.verify(using: app.backend) {
                verified += 1
                await app.completeSignIn()
            }
        }
    }
}
