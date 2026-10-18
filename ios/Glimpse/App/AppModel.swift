import Foundation
import Observation
import UIKit

enum AppTab: Hashable {
    case discover
    case connections
    case profile
}

/// Why the Glimpse+ paywall is being shown (drives its headline).
enum PaywallReason: String, Identifiable {
    case outOfViews
    /// Glimpse Gold features (Spotlight, Rewind, Travel mode, clip insights).
    case gold
    case freeze
    case secondChance
    case settings

    var id: String { rawValue }
}

/// Top-level session state: who is signed in, whether their device passed
/// DeviceCheck, and whether onboarding is complete.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case launching
        case signedOut
        case needsProfile
        case needsVideo
        /// Held for review after AI-generated media reports; a selfie check restores access.
        case needsVerification
        case blocked(String)
        case ready
    }

    let backend: any GlimpseBackend
    let config: AppConfig?
    let launch: LaunchOptions

    private(set) var phase: Phase = .launching
    private(set) var profile: UserProfile?
    var selectedTab: AppTab = .discover
    var connectionsPath: [MatchSummary] = []
    /// Bumped whenever matches change elsewhere (e.g. a new match from the feed).
    private(set) var matchesVersion = 0
    var paywall: PaywallReason?
    var showLikesYou = false
    /// Glimpse's own alerts choice, shown once before iOS's permission prompt.
    var askForAlerts = false
    /// A rare, in-context offer to turn on one kind of alert.
    var alertNudge: AlertNudge?
    private let nudges = AlertNudges()
    let store = StoreManager()
    private var readyTasksStarted = false

    var isDemo: Bool { backend.isDemo }

    init(launch: LaunchOptions = .current) {
        self.launch = launch
        if let seconds = launch.clipSeconds {
            UserDefaults.standard.set(seconds, forKey: PlaybackPreferences.clipSecondsKey)
        }
        let config = launch.forceDemo ? nil : AppConfig.load()
        self.config = config
        if let config {
            backend = SupabaseBackend(config: config)
        } else {
            let seeded = launch.screen != nil && launch.screen != .welcome
            backend = DemoBackend(seeded: seeded, withVideos: launch.screen != .firstVideo, videoCalls: launch.screen == .videoCall)
        }
        switch launch.screen {
        case .connections, .chat, .videoCall: selectedTab = .connections
        case .likes:
            selectedTab = .connections
            showLikesYou = true
        case .profile, .settings, .addVideo: selectedTab = .profile
        case .paywall: paywall = .settings
        default: selectedTab = .discover
        }
    }

    func start() async {
        guard phase == .launching else { return }
        guard await backend.restoreSession() != nil else {
            phase = .signedOut
            return
        }
        await completeSignIn()
    }

    /// Runs after OTP verification and on every cold launch with a session.
    func completeSignIn() async {
        do {
            let verdict = try await backend.attestDevice()
            guard verdict.allowed else {
                phase = .blocked(blockedMessage(for: verdict.reason))
                return
            }
            if let state = try? await backend.accountState() {
                if state.needsSyntheticMediaVerification {
                    phase = .needsVerification
                    return
                }
                if state.status != "active" {
                    phase = .blocked(blockedMessage(for: state.reason ?? state.status))
                    return
                }
            }
            profile = try await backend.fetchMyProfile()
            route()
        } catch {
            phase = .blocked(GlimpseError.describe(error))
        }
    }

    func profileCreated(_ profile: UserProfile) {
        self.profile = profile
        route()
    }

    func refreshProfile() async {
        if let fresh = try? await backend.fetchMyProfile() {
            profile = fresh
            if phase == .needsVideo { route() }
        }
    }

    func signOut() async {
        await PushNotifications.shared.signOut()
        await backend.signOut()
        profile = nil
        connectionsPath = []
        selectedTab = .discover
        phase = .signedOut
    }

    /// Permanently deletes the account (App Store requirement), then returns to the welcome screen.
    func deleteAccount() async throws {
        track("account_deleted")
        await PushNotifications.shared.signOut()
        try await backend.deleteAccount()
        profile = nil
        connectionsPath = []
        selectedTab = .discover
        phase = .signedOut
    }

    /// One-time setup once the user reaches the main app: push, location, purchases, telemetry.
    func didBecomeReady() async {
        guard !readyTasksStarted else { return }
        readyTasksStarted = true
        PushNotifications.shared.app = self
        DiagnosticsReporter.backend = backend
        store.startListening(backend: backend)
        track("app_open")
        Task { await VibeRecordingUploads.uploadPending(using: backend) }

        if launch.screen == .alerts {
            askForAlerts = true
            return
        }
        if launch.screen == .alertNudge {
            alertNudge = AlertNudge(topic: .vibeCheck, name: "Maya")
            return
        }
        guard launch.screen == nil else { return } // keep scripted screenshot runs prompt-free
        if await PushNotifications.shared.needsToAsk() {
            // Asked once. After that, only rare in-context offers (see offerAlerts).
            if !nudges.hasMadeFirstChoice { askForAlerts = true }
        } else {
            await PushNotifications.shared.requestAuthorizationAndRegister()
        }
        if let coordinate = await LocationService.approximateCoordinate() {
            try? await backend.updateLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    /// What buzzes the phone (Settings, or the first-time alerts sheet).
    func setPushScope(_ scope: PushScope) async {
        profile?.pushScope = scope
        try? await backend.setPushScope(scope)
    }

    func setVideoCallsEnabled(_ enabled: Bool) async {
        profile?.videoCallsEnabled = enabled
        try? await backend.setVideoCallsEnabled(enabled)
        track("video_calls_setting", ["enabled": "\(enabled)"])
    }

    func setDataConsent(aiTraining: Bool, sharing: Bool) async {
        profile?.consentAiTraining = aiTraining
        profile?.consentDataSharing = sharing
        try? await backend.setDataConsent(aiTraining: aiTraining, sharing: sharing)
    }

    /// From the alerts sheet: remember the choice, then (if any) iOS's own prompt.
    func choseAlerts(_ scope: PushScope?) async {
        askForAlerts = false
        nudges.recordFirstChoice()
        guard let scope else { return }
        await setPushScope(scope)
        await PushNotifications.shared.requestAuthorizationAndRegister()
        track("alerts_chosen", ["scope": scope.rawValue])
    }

    func setPushExtras(_ extras: [AlertExtra]) async {
        profile?.pushExtras = extras
        try? await backend.setPushExtras(extras)
    }

    /// Offers one kind of alert at the moment it matters, only if it's off right
    /// now and the pacing rules allow it. Most calls show nothing, on purpose.
    func offerAlerts(_ topic: AlertNudge.Topic, name: String) async {
        guard launch.screen == nil, alertNudge == nil, !askForAlerts, nudges.mayAsk(topic) else { return }
        let scope = profile?.pushScope ?? .all
        let extras = profile?.pushExtras ?? []
        let authorized = await PushNotifications.shared.isAuthorized()
        let relevant = switch topic {
        case .vibeCheck: authorized && scope == .messages && !extras.contains(.vibeCheck)
        case .newMatch: authorized && scope == .messages && !extras.contains(.newMatch)
        case .replies: !authorized || scope == .none
        }
        guard relevant else { return }
        nudges.recordAsked(topic)
        alertNudge = AlertNudge(topic: topic, name: name)
        track("alert_nudge_shown", ["topic": topic.rawValue])
    }

    func answerNudge(_ nudge: AlertNudge, accepted: Bool, never: Bool) async {
        alertNudge = nil
        nudges.recordAnswer(nudge.topic, accepted: accepted, never: never)
        track("alert_nudge_answered", ["topic": nudge.topic.rawValue, "accepted": "\(accepted)", "never": "\(never)"])
        guard accepted else { return }
        if let extra = nudge.extra {
            var extras = profile?.pushExtras ?? []
            if !extras.contains(extra) { extras.append(extra) }
            await setPushExtras(extras)
            return
        }
        // Replies: alerts were off. Turn on messages, then iOS's own prompt
        // (or iOS Settings, if alerts were switched off there).
        if (profile?.pushScope ?? .all) == .none { await setPushScope(.messages) }
        if await PushNotifications.shared.isDenied() {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                _ = await UIApplication.shared.open(url)
            }
        } else {
            await PushNotifications.shared.requestAuthorizationAndRegister()
        }
    }

    func handleNotificationTap(kind: String?, matchID: UUID?) {
        switch kind {
        case "liked_you":
            selectedTab = .connections
            showLikesYou = true
        case "video_unavailable":
            selectedTab = .profile
        default:
            guard let matchID else { return }
            Task {
                if let match = try? await backend.fetchMatches().first(where: { $0.matchID == matchID }) {
                    openChat(match)
                } else {
                    selectedTab = .connections
                }
            }
        }
    }

    /// Fire-and-forget first-party analytics.
    func track(_ event: String, _ properties: [String: String] = [:]) {
        let backend = backend
        Task { await backend.track(event, properties: properties) }
    }

    func retryLaunch() async {
        phase = .launching
        await start()
    }

    func openChat(_ match: MatchSummary) {
        matchesDidChange()
        selectedTab = .connections
        connectionsPath = [match]
    }

    private var launchChatConsumed = false

    /// For `-screen chat` launches: opens the most recent conversation once.
    func openLaunchChatIfNeeded(from conversations: [MatchSummary]) {
        guard launch.screen == .chat || launch.screen == .videoCall, !launchChatConsumed, let first = conversations.first else { return }
        launchChatConsumed = true
        connectionsPath = [first]
    }

    func matchesDidChange() {
        matchesVersion += 1
    }

    private func route() {
        guard let profile else {
            phase = .needsProfile
            return
        }
        if profile.isOnboarded, phase == .needsVideo {
            track("onboarding_completed")
        }
        phase = profile.isOnboarded ? .ready : .needsVideo
    }

    private func blockedMessage(for reason: String?) -> String {
        switch reason {
        case "device_blacklisted":
            "This iPhone is no longer allowed to create Glimpse accounts after a serious violation of our community rules."
        case "account_terminated", "terminated":
            "This account was closed for violating our community rules."
        case "underage_review":
            "Your account is paused while we review it. We'll be in touch soon."
        case "safety_review":
            "Your account is on hold while our safety team reviews a report about a conversation. We'll let you know the outcome."
        default:
            "We couldn't verify this device."
        }
    }
}
