import SwiftUI

struct AuthFlowView: View {
    @Environment(AppModel.self) private var app
    @State private var model = AuthFlowModel()

    var body: some View {
        ZStack {
            switch model.step {
            case .welcome:
                WelcomeView {
                    model.step = .phone
                }
                .transition(.opacity)
            case .phone:
                PhoneEntryView(model: model)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .code:
                CodeEntryView(model: model)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.3), value: model.step)
    }
}
