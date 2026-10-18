import AVFoundation
import SwiftUI

@main
struct GlimpseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var app = AppModel()

    init() {
        // Feed audio follows the silent switch, like other short-video apps.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .onAppear { ScreenRecordingShield.shared.start() }
                .preferredColorScheme(.dark)
                .tint(Palette.mint)
        }
    }
}
