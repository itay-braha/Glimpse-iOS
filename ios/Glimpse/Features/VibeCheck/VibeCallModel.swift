import AVFoundation
import Observation
import UIKit

/// Drives one 3-Minute Vibe Check: lobby -> both ready -> peer connection ->
/// hard stop at 00:00 (anchored on server time) -> private survey.
@MainActor
@Observable
final class VibeCallModel {
    enum Phase: Equatable {
        case preparing
        case lobby
        case connecting
        case live
        case ended
        case failed(String)
    }

    /// General topics, after the ones drawn from both profiles.
    static let icebreakers = [
        String(localized: "Worst travel disaster?"),
        String(localized: "The coffee order that reveals your true personality"),
        String(localized: "What's the last thing that made you laugh out loud?"),
        String(localized: "Most controversial food opinion?"),
        String(localized: "Describe your perfect lazy Sunday"),
        String(localized: "What were you obsessed with at 12?"),
        String(localized: "Which song would play when you walk into a room?"),
        String(localized: "Best thing you've eaten this month?"),
        String(localized: "What's a small thing that makes your whole day?"),
        String(localized: "Window seat or aisle, and defend it"),
        String(localized: "The best advice you ever ignored"),
        String(localized: "What would you do with a free Tuesday?"),
    ]

    /// Topics on screen by default in a Vibe Check (one tap to hide, remembered).
    static let topicsPreferenceKey = "vibe.topicsEnabled"

    let match: MatchSummary
    private(set) var phase: Phase = .preparing
    private(set) var meReady = false
    private(set) var otherReady = false
    private(set) var remoteVideoArrived = false
    private(set) var secondsLeft = 180
    private(set) var thirtySecondWarning = false
    /// Our screen is being recorded/mirrored: hide their video from the capture.
    private(set) var localCaptureActive = false
    /// They are recording, or just took a screenshot: we stop sending video.
    private(set) var remoteCaptureActive = false
    /// Conversation topics: from both profiles first, then general ones.
    private(set) var topics: [String] = VibeCallModel.icebreakers.shuffled()
    private(set) var topicIndex = 0
    /// On by default; one tap hides them (remembered for next time).
    private(set) var showTopics = true
    /// Agreed to the private safety recording (required to join).
    var agreedToSafetyRecording = false
    /// Both videos are excluded from screenshots/recordings on this iOS version.
    let captureProtected = SecureCanvas(frame: .zero).isProtected

    private(set) var client: WebRTCClient?
    private let backend: any GlimpseBackend
    private let myID: String
    private var signaling: VibeSignalChannel?
    private var listenTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var readyPingTask: Task<Void, Never>?
    private var screenshotObserver: (any NSObjectProtocol)?
    private var offerSent = false
    private var endsAt: Date?
    private var recorders: [VibeSafetyRecorder] = []

    var isDemo: Bool { backend.isDemo }

    /// The participant with the lower id creates the offer, so exactly one side does.
    private var isOfferer: Bool { myID < match.otherUserID.uuidString.lowercased() }

    init(match: MatchSummary, myID: UUID, backend: any GlimpseBackend) {
        self.match = match
        self.myID = myID.uuidString.lowercased()
        self.backend = backend
        showTopics = UserDefaults.standard.object(forKey: Self.topicsPreferenceKey) as? Bool ?? true
    }

    var clockText: String {
        String(format: "%02d:%02d", secondsLeft / 60, secondsLeft % 60)
    }

    // MARK: Lifecycle

    func prepare() async {
        configureAudio(active: true)
        if !backend.isDemo {
            guard await CameraController.requestAccess() else {
                phase = .failed(String(localized: "Glimpse needs camera and microphone access for the Vibe Check."))
                return
            }
            do {
                let servers = try await backend.vibeIceServers(matchID: match.matchID)
                guard let client = WebRTCClient(iceServers: servers) else {
                    phase = .failed(String(localized: "Couldn't start the video connection."))
                    return
                }
                wire(client)
                client.startCapture()
                self.client = client
            } catch {
                phase = .failed(GlimpseError.describe(error))
                return
            }
        }

        await loadTopics()
        let channel = await backend.openVibeSignaling(matchID: match.matchID)
        signaling = channel
        listenTask = Task { [weak self] in
            for await signal in channel.signals {
                self?.handle(signal)
            }
        }
        observeScreenshots()
        phase = .lobby
    }

    /// "I'm ready": announced until the other side answers, so late joiners still see it.
    func markReady() {
        guard !meReady, agreedToSafetyRecording else { return }
        meReady = true
        readyPingTask = Task { [weak self] in
            while let self, !Task.isCancelled, !self.otherReady || !self.offerSent && self.isOfferer {
                await self.send(VibeSignal(kind: .ready, sender: ""))
                try? await Task.sleep(for: .seconds(2))
                if self.phase != .lobby && self.phase != .connecting { break }
            }
        }
        maybeStartNegotiation()
    }

    func end(sendHangup: Bool = true) {
        guard phase != .ended else { return }
        phase = .ended
        clockTask?.cancel()
        readyPingTask?.cancel()
        listenTask?.cancel()
        if let screenshotObserver {
            NotificationCenter.default.removeObserver(screenshotObserver)
        }
        client?.onLocalFrame = nil
        client?.onRemoteFrame = nil
        client?.close()
        client = nil
        finishRecording()
        let channel = signaling
        signaling = nil
        Task {
            if sendHangup {
                await channel?.send(VibeSignal(kind: .hangup, sender: ""))
            }
            await channel?.close()
        }
        configureAudio(active: false)
    }

    var currentTopic: String {
        topics.isEmpty ? Self.icebreakers[0] : topics[topicIndex % topics.count]
    }

    func nextTopic() {
        topicIndex = (topicIndex + 1) % max(topics.count, 1)
    }

    /// Hiding (or showing) topics is remembered for future Vibe Checks.
    func setShowTopics(_ show: Bool) {
        showTopics = show
        UserDefaults.standard.set(show, forKey: Self.topicsPreferenceKey)
    }

    /// Topics from both profiles (their clips, what you both wrote, your city) lead.
    private func loadTopics() async {
        let personal = (try? await backend.vibeTopics(matchID: match.matchID)) ?? []
        let general = Self.icebreakers.filter { !personal.contains($0) }.shuffled()
        topics = personal.shuffled() + general
        topicIndex = 0
    }

    // MARK: Signaling

    private func handle(_ signal: VibeSignal) {
        switch signal.kind {
        case .ready:
            otherReady = true
            maybeStartNegotiation()
        case .offer:
            guard let sdp = signal.sdp, let client else { return }
            phase = .connecting
            client.handleRemoteOffer(sdp) { [weak self] answer in
                guard let answer else { return }
                Task { @MainActor in
                    await self?.send(VibeSignal(kind: .answer, sender: "", sdp: answer))
                }
            }
        case .answer:
            if let sdp = signal.sdp { client?.handleRemoteAnswer(sdp) }
        case .candidate:
            if let sdp = signal.sdp, let index = signal.sdpMLineIndex {
                client?.addRemoteCandidate(sdp: sdp, mLineIndex: index, mid: signal.sdpMid)
            }
        case .capture:
            remoteCaptureActive = signal.flag == true
            client?.setVideoEnabled(!remoteCaptureActive)
        case .screenshot:
            flashRemoteCaptureWarning()
        case .hangup:
            end(sendHangup: false)
        }
    }

    private func maybeStartNegotiation() {
        guard meReady, otherReady, phase == .lobby || phase == .connecting else { return }
        if backend.isDemo {
            Task { await goLive() }
            return
        }
        phase = .connecting
        guard isOfferer, !offerSent, let client else { return }
        offerSent = true
        client.makeOffer { [weak self] sdp in
            guard let sdp else { return }
            Task { @MainActor in
                await self?.send(VibeSignal(kind: .offer, sender: "", sdp: sdp))
            }
        }
    }

    private func wire(_ client: WebRTCClient) {
        client.onLocalCandidate = { [weak self] sdp, index, mid in
            Task { @MainActor in
                await self?.send(VibeSignal(kind: .candidate, sender: "", sdp: sdp, sdpMLineIndex: index, sdpMid: mid))
            }
        }
        client.onConnectionChange = { [weak self] connected in
            Task { @MainActor in
                guard let self else { return }
                if connected {
                    await self.goLive()
                } else if self.phase == .live || self.phase == .connecting {
                    self.end(sendHangup: false)
                }
            }
        }
        client.onRemoteVideo = { [weak self] in
            Task { @MainActor in self?.remoteVideoArrived = true }
        }
    }

    private func send(_ signal: VibeSignal) async {
        await signaling?.send(signal)
    }

    // MARK: Clock

    private func goLive() async {
        guard phase != .live, phase != .ended else { return }
        phase = .live
        readyPingTask?.cancel()
        startRecording()
        do {
            let clock = try await backend.vibeMarkStarted(matchID: match.matchID)
            // Translate the server's end time into local time (clock skew safe).
            let skew = clock.serverNow.timeIntervalSinceNow
            endsAt = clock.endsAt.addingTimeInterval(-skew)
        } catch {
            endsAt = Date.now.addingTimeInterval(180)
        }
        startClock()
    }

    private func startClock() {
        clockTask = Task { [weak self] in
            while let self, !Task.isCancelled, let endsAt = self.endsAt {
                let left = max(Int(endsAt.timeIntervalSinceNow.rounded(.up)), 0)
                self.secondsLeft = left
                if left <= 30 && !self.thirtySecondWarning {
                    self.thirtySecondWarning = true
                }
                self.checkLocalCapture()
                if left == 0 {
                    self.end()
                    return
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    // MARK: Anti-capture guard

    private func checkLocalCapture() {
        let capturing = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .contains { $0.traitCollection.sceneCaptureState == .active }
        guard capturing != localCaptureActive else { return }
        localCaptureActive = capturing
        Task { await send(VibeSignal(kind: .capture, sender: "", flag: capturing)) }
        if capturing {
            let matchID = match.matchID
            Task { await backend.logVibeCapture(matchID: matchID, kind: "screen_recording") }
        }
    }

    private func observeScreenshots() {
        screenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.send(VibeSignal(kind: .screenshot, sender: ""))
                await self.backend.logVibeCapture(matchID: self.match.matchID, kind: "screenshot")
            }
        }
    }

    private func flashRemoteCaptureWarning() {
        remoteCaptureActive = true
        client?.setVideoEnabled(false)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, self.phase == .live else { return }
            self.remoteCaptureActive = false
            self.client?.setVideoEnabled(true)
        }
    }

    // MARK: Safety recording

    /// Records what this phone sends (uploaded piece by piece during the call) and a
    /// low-quality backup of what it receives, from the moment the call is live.
    private func startRecording() {
        guard let client, recorders.isEmpty else { return }
        let matchID = match.matchID
        let backend = backend
        let deliver: @Sendable (VibeSafetyRecorder.Segment) -> Void = { segment in
            Task { @MainActor in
                VibeRecordingUploads.enqueue(segment, matchID: matchID)
                if segment.stream == .own {
                    await VibeRecordingUploads.uploadPending(using: backend)
                }
            }
        }
        let own = VibeSafetyRecorder(stream: .own, onSegment: deliver)
        let received = VibeSafetyRecorder(stream: .received, onSegment: deliver)
        own.start()
        received.start()
        client.onLocalFrame = { @Sendable frame in own.append(frame) }
        client.onRemoteFrame = { @Sendable frame in received.append(frame) }
        recorders = [own, received]
    }

    /// Closes the last pieces; anything not yet uploaded is retried on later launches.
    private func finishRecording() {
        let recorders = recorders
        self.recorders = []
        guard !recorders.isEmpty else { return }
        let backend = backend
        Task { @MainActor in
            for recorder in recorders { await recorder.finish() }
            await VibeRecordingUploads.uploadPending(using: backend)
        }
    }

    // MARK: Audio

    private func configureAudio(active: Bool) {
        let session = AVAudioSession.sharedInstance()
        if active {
            try? session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker])
            try? session.setActive(true)
        } else {
            try? session.setCategory(.ambient, mode: .moviePlayback)
        }
    }
}
