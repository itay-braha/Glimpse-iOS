import UIKit
import UserNotifications

/// Registers for APNs, uploads the device token, and routes notification taps
/// (e.g. a new message) to the right chat.
@MainActor
final class PushNotifications: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotifications()

    weak var app: AppModel?
    private var lastToken: String?

    private var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    /// Asks once (after onboarding, when the value is obvious) and registers.
    func requestAuthorizationAndRegister() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted { UIApplication.shared.registerForRemoteNotifications() }
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        default:
            break
        }
    }

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        lastToken = token
        guard let backend = app?.backend else { return }
        let environment = environment
        Task { try? await backend.registerPushToken(token, environment: environment) }
    }

    func signOut() async {
        if let lastToken, let backend = app?.backend {
            await backend.unregisterPushToken(lastToken)
        }
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let matchID = (info["match_id"] as? String).flatMap(UUID.init(uuidString:))
        let kind = info["kind"] as? String
        await MainActor.run {
            PushNotifications.shared.app?.handleNotificationTap(kind: kind, matchID: matchID)
        }
    }
}
