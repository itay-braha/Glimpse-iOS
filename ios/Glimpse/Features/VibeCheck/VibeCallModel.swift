import AVFoundation
import Observation
import UIKit

/// Drives one call: lobby -> both ready -> peer connection -> hard stop at 00:00
/// (anchored on server time). A 3-Minute Vibe Check ends in a private survey; a
/// video call (up to 15 minutes, after a good Vibe Check) just ends.
@MainActor
@Observable
final class VibeCallModel {
    enum Kind: Equatable {
        case vibeCheck
        /// A ringing or live video call.
        case videoCall(UUID)
    }

    enum Phase: Equatable {
        case preparing
        case lobby
        case connecting
        case live
        case ended
        case failed(String)
    }

    static let icebreakers = [
        "Worst travel disaster?",
        "The coffee order that reveals your true personality",
        "What's the last thing that made you laugh out loud?",
        "Most controversial food opinion?",
        "Describe your perfect lazy Sunday",
        "What were you obsessed with at 12?",
        "Which song would play when you walk into a room?",
        "Best thing you've eaten this month?",
    ]

    let match: MatchSummary
    let kind: Kind
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
    var icebreakerIndex = 0
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

    var callID: UUID? {
        switch kind {
        case let .videoCall(id): id
        case .vibeCheck: nil
        }
    }

    var isVideoCall: Bool { callID != nil }

    /// Call length: 3 minutes for a Vibe Check, up to 15 for a video call.
    var totalSeconds: Int { isVideoCall ? 15 * 60 : 180 }

    private var watchTask: Task<Void, Never>?

    /// - Parameter recordingAgreed: for video calls, the safety recording is agreed once per match.
    init(match: MatchSummary, myID: UUID, backend: any GlimpseBackend, kind: Kind = .vibeCheck, recordingAgreed: Bool = false) {
        self.match = match
        self.kind = kind
        self.myID = myID.uuidString.lowercased()
        self.backend = backend
        icebreakerIndex = Int.random(in: 0..<Self.icebreakers.count)
        if case .videoCall = kind {
            secondsLeft = 15 * 60
            agreedToSafetyRecording = recordingAgreed
        }
    }

    var clockText: String {
        String(format: "%02d:%02d", secondsLeft / 60, secondsLeft % 60)
    }

    // MARK: Lifecycle

    func prepare() async {
        configureAudio(active: true)
        if !backend.isDemo {
            guard await CameraController.requestAccess() else {
                phase = .failed("Glimpse needs camera and microphone access for the Vibe Check.")
                return
            }
            do {
                let servers = try await backend.vibeIceServers(matchID: match.matchID)
                guard let client = WebRTCClient(iceServers: servers) else {
                    phase = .failed("Couldn't start the video connection.")
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

        let channel = await backend.openVibeSignaling(matchID: match.matchID)
        signaling = channel
        listenTask = Task { [weak self] in
            for await signal in channel.signals {
                self?.handle(signal)
            }
        }
        observeScreenshots()
        phase = .lobby
        if isVideoCall {
            watchCall()
            // Agreed before with this match: straight in, like a phone call.
            if agreedToSafetyRecording { markReady() }
        }
    }

    /// While a video call is ringing or live, notices if the other side declined,
    /// missed it, blocked calls or hung up from another screen.
    private func watchCall() {
        guard let callID else { return }
        let matchID = match.matchID
        let name = match.displayName
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, self.phase != .ended else { return }
                guard let state = try? await self.backend.videoCallState(matchID: matchID) else { continue }
                if state.activeCall?.id != callID {
                    if self.phase == .live {
                        self.end(sendHangup: false)
                    } else {
                        self.fail("\(name) can't talk right now.")
                    }
                    return
                }
            }
        }
    }

    private func fail(_ message: String) {
        end(sendHangup: false)
        phase = .failed(message)
    }

    /// "I'm ready": announced until the other side answers, so late joiners still see it.
    func markReady() {
        guard !meReady, agreedToSafetyRecording else { return }
        meReady = true
        if isVideoCall {
            let matchID = match.matchID
            Task { try? await backend.agreeVideoCallRecording(matchID: matchID) }
        }
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
        watchTask?.cancel()
        if let callID {
            let backend = backend
            Task { await backend.endVideoCall(callID: callID) }
        }
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

    func nextIcebreaker() {
        icebreakerIndex = (icebreakerIndex + 1) % Self.icebreakers.count
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
            let clock: VibeClock
            if let callID {
                clock = try await backend.videoCallClock(callID: callID)
            } else {
                clock = try await backend.vibeMarkStarted(matchID: match.matchID)
            }
            // Translate the server's end time into local time (clock skew safe).
            let skew = clock.serverNow.timeIntervalSinceNow
            endsAt = clock.endsAt.addingTimeInterval(-skew)
        } catch {
            endsAt = Date.now.addingTimeInterval(Double(totalSeconds))
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
        let callID = callID
        let backend = backend
        let deliver: @Sendable (VibeSafetyRecorder.Segment) -> Void = { segment in
            Task { @MainActor in
                VibeRecordingUploads.enqueue(segment, matchID: matchID, callID: callID)
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
