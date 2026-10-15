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
    }

    var forceDemo = false
    var screen: Screen?

    static var current: LaunchOptions {
        let arguments = ProcessInfo.processInfo.arguments
        var options = LaunchOptions()
        options.forceDemo = arguments.contains("-demo")
        if let index = arguments.firstIndex(of: "-screen"), arguments.indices.contains(index + 1) {
            options.screen = Screen(rawValue: arguments[index + 1])
        }
        return options
    }
}
