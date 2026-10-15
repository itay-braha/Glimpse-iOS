import SwiftUI

struct PhoneEntryView: View {
    @Environment(AppModel.self) private var app
    @Bindable var model: AuthFlowModel
    @FocusState private var focused: Bool

    var body: some View {
        OnboardingScaffold(
            title: "What's your number?",
            subtitle: "We'll text you a code. Glimpse only accepts real mobile numbers, so no VOIP or virtual numbers.",
            onBack: { model.step = .welcome }
        ) {
            HStack(spacing: 10) {
                Menu {
                    Picker("Country", selection: $model.dialCode) {
                        ForEach(DialCode.all) { dial in
                            Text("\(dial.flag)  +\(dial.code)").tag(dial)
                        }
                    }
                } label: {
                    Text("\(model.dialCode.flag) +\(model.dialCode.code)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 58)
                        .background(Palette.surfaceRaised, in: .rect(cornerRadius: 16))
                }
                .accessibilityLabel("Country code +\(model.dialCode.code)")

                TextField("Mobile number", text: $model.nationalNumber)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .font(.title3.weight(.semibold))
                    .focused($focused)
                    .padding(.horizontal, 16)
                    .frame(height: 58)
                    .background(Palette.surfaceRaised, in: .rect(cornerRadius: 16))
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
    }
}
