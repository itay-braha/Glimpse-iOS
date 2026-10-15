import Foundation

/// Launch arguments used for demo runs and automated screenshots, e.g.
/// `-demo -screen chat` or `-screen welcome`.
struct LaunchOptions: Sendable {
    enum Screen: String, Sendable {
        case welcome
        case feed
        case match
        case connections
        case chat
        case profile
        case likes
        case paywall
        case settings
        /// Profile with the "Let others get a Glimpse of YOU" sheet open.
        case addVideo
        /// Onboarding's last step (the video hub) for a signed-in member with no videos.
        case firstVideo
        /// Feed with the "what should buzz?" sheet up.
        case alerts
    }

    var forceDemo = false
    var screen: Screen?
    /// Show the one-time feed tips even in scripted runs (`-showTips`).
    var showTips = false
    /// Clip time for scripted runs (`-clipSeconds 12`), so slow simulators don't race the timer.
    var clipSeconds: Double?

    static var current: LaunchOptions {
        let arguments = ProcessInfo.processInfo.arguments
        var options = LaunchOptions()
        options.forceDemo = arguments.contains("-demo")
        options.showTips = arguments.contains("-showTips")
        if let index = arguments.firstIndex(of: "-clipSeconds"), arguments.indices.contains(index + 1) {
            options.clipSeconds = Double(arguments[index + 1])
        }
        if let index = arguments.firstIndex(of: "-screen"), arguments.indices.contains(index + 1) {
            options.screen = Screen(rawValue: arguments[index + 1])
        }
        return options
    }
}
