import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            Palette.midnight.ignoresSafeArea()

            switch app.phase {
            case .launching:
                LaunchView()
            case .signedOut:
                AuthFlowView()
            case .needsProfile:
                ProfileBasicsView()
            case .needsVideo:
                FirstVideoView()
            case .needsVerification:
                VerifyToContinueView()
            case let .blocked(message):
                BlockedView(message: message)
            case .ready:
                MainTabView()
            }
        }
        .animation(.smooth(duration: 0.35), value: app.phase)
        .task { await app.start() }
    }
}

private struct LaunchView: View {
    var body: some View {
        Wordmark(size: 44)
    }
}

private struct BlockedView: View {
    @Environment(AppModel.self) private var app
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.pink)
            Text("Access restricted")
                .font(.glimpseTitle)
            Text(message)
                .font(.glimpseBody)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await app.retryLaunch() }
            }
            .buttonStyle(.glimpseSecondary)
            .padding(.top, 12)
        }
        .padding(32)
    }
}
