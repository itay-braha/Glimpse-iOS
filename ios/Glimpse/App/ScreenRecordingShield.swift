import SwiftUI
import UIKit

/// Screen recording isn't allowed anywhere in Glimpse (screenshots are fine, except in a
/// Vibe Check, which blocks those too). iOS doesn't let an app stop a recording from
/// starting, so while the screen is being recorded or mirrored, a window above
/// everything, sheets and calls included, covers the app: the recording only shows this.
@MainActor
final class ScreenRecordingShield {
    static let shared = ScreenRecordingShield()

    private var window: UIWindow?
    private var observer: (any NSObjectProtocol)?

    private init() {}

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UIScreen.capturedDidChangeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in ScreenRecordingShield.shared.update() }
        }
        update()
    }

    /// Recording, AirPlay or mirroring of any of our scenes.
    private var isCaptured: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .contains { $0.traitCollection.sceneCaptureState == .active }
    }

    private func update() {
        if isCaptured {
            show()
        } else {
            window?.isHidden = true
            window = nil
        }
    }

    private func show() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        else { return }
        let shield = UIWindow(windowScene: scene)
        shield.windowLevel = .alert + 1
        let host = UIHostingController(rootView: ShieldView())
        host.view.backgroundColor = .black
        shield.rootViewController = host
        shield.isHidden = false
        window = shield
    }
}

private struct ShieldView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "record.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Palette.pink)
                    .accessibilityHidden(true)
                Text("Screen recording isn't allowed in Glimpse")
                    .font(.glimpseTitle2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Stop the recording to keep using the app. This protects everyone's videos and conversations.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(32)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recordingShield")
    }
}
