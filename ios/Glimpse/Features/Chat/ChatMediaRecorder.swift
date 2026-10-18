@preconcurrency import AVFoundation
import Observation

/// Records a voice message (microphone) or a round video note (selfie camera)
/// in the chat, the way WhatsApp does:
///   * hold the button to record, release to send;
///   * slide left to cancel;
///   * slide up to lock, so long recordings don't need a finger held down; then
///     trash or send;
///   * recordings stop at their cap (2 minutes voice, 60 seconds video) and send.
/// Nothing leaves the phone until it's sent; cancelled recordings are deleted.
@MainActor
@Observable
final class ChatMediaRecorder {
    enum Phase: Equatable {
        case idle
        /// Finger down, recording.
        case holding
        /// Locked: recording hands-free until trash or send.
        case locked
    }

    struct Recording: Sendable {
        let kind: MessageKind
        let fileURL: URL
        let duration: Double
    }

    private(set) var phase: Phase = .idle
    private(set) var kind: MessageKind = .voice
    private(set) var startedAt: Date?
    /// Where the finger is, relative to where it went down (for the slide hints).
    var drag: CGSize = .zero
    var errorMessage: String?

    /// The selfie camera for video notes (its session feeds the round preview).
    let camera = CameraController(maxDuration: MessageKind.video.maxDuration)
    private var audio: AVAudioRecorder?
    private var audioURL: URL?
    private var videoResult: Result<URL, any Error>?
    private var videoWaiters: [CheckedContinuation<Result<URL, any Error>?, Never>] = []
    private var capTask: Task<Void, Never>?
    /// Demo builds on a simulator have no camera or microphone: they send a sample.
    var demoFallback = false

    static let lockDistance: CGFloat = 70
    static let cancelDistance: CGFloat = 110

    var isRecording: Bool { phase != .idle }

    var elapsed: TimeInterval {
        startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
    }

    // MARK: Start

    /// Starts recording; returns false when the camera or microphone isn't available.
    func begin(_ kind: MessageKind, locked: Bool = false) async -> Bool {
        guard phase == .idle else { return false }
        self.kind = kind
        errorMessage = nil
        drag = .zero
        let started = kind == .video ? await startVideo() : await startVoice()
        guard started || demoFallback else { return false }
        startedAt = .now
        phase = locked ? .locked : .holding
        capTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(kind.maxDuration))
            guard let self, !Task.isCancelled, self.phase != .idle else { return }
            self.reachedCap = true
        }
        return true
    }

    /// Set when the cap is reached; the composer sends the recording.
    var reachedCap = false

    private func startVoice() async -> Bool {
        #if targetEnvironment(simulator)
        // Demo runs on a simulator send a sample instead of asking for the microphone.
        if demoFallback { return false }
        #endif
        guard await AVAudioApplication.requestRecordPermission() else {
            errorMessage = "Glimpse needs microphone access for voice messages. You can turn it on in Settings."
            return false
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appending(path: "voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
        ]
        guard let recorder = try? AVAudioRecorder(url: url, settings: settings),
              recorder.record(forDuration: MessageKind.voice.maxDuration)
        else { return false }
        audio = recorder
        audioURL = url
        return true
    }

    private func startVideo() async -> Bool {
        guard CameraController.isAvailable else { return false }
        guard await CameraController.requestAccess() else {
            errorMessage = "Glimpse needs camera and microphone access for video messages. You can turn it on in Settings."
            return false
        }
        do {
            try await camera.start()
        } catch {
            return false
        }
        videoResult = nil
        camera.startRecording { [weak self] result in
            Task { @MainActor in self?.videoFinished(result) }
        }
        return true
    }

    private func videoFinished(_ result: Result<URL, any Error>) {
        videoResult = result
        let waiters = videoWaiters
        videoWaiters = []
        waiters.forEach { $0.resume(returning: result) }
    }

    // MARK: Gestures

    func lock() {
        guard phase == .holding else { return }
        phase = .locked
    }

    /// Discards the recording; nothing is sent.
    func cancel() {
        guard phase != .idle else { return }
        stopCapture()
        if kind == .video { camera.stop() }
        if let audioURL { try? FileManager.default.removeItem(at: audioURL) }
        reset()
    }

    /// Stops and returns the file to send (nil for an accidental tap or a failure).
    func finish() async -> Recording? {
        guard phase != .idle else { return nil }
        let kind = kind
        let duration = min(elapsed, kind.maxDuration)
        stopCapture()
        defer { reset() }
        guard duration >= MessageKind.minDuration else {
            errorMessage = "Hold to record, release to send."
            return nil
        }

        if kind == .voice {
            if let audioURL, FileManager.default.fileExists(atPath: audioURL.path()) {
                return Recording(kind: .voice, fileURL: audioURL, duration: duration)
            }
        } else if let raw = await waitForVideo(), let mp4 = await Self.compress(raw) {
            let measured = (try? await AVURLAsset(url: mp4).load(.duration).seconds) ?? duration
            return Recording(kind: .video, fileURL: mp4, duration: min(max(measured, MessageKind.minDuration), kind.maxDuration))
        }
        if demoFallback, let sample = DemoData.chatSample(kind) {
            return Recording(kind: kind, fileURL: sample, duration: min(duration, kind.maxDuration))
        }
        errorMessage = "That recording didn't work. Try again."
        return nil
    }

    private func stopCapture() {
        capTask?.cancel()
        capTask = nil
        if let audio {
            audio.stop()
            self.audio = nil
        }
        if kind == .video {
            camera.stopRecording()
        }
    }

    private func waitForVideo() async -> URL? {
        guard CameraController.isAvailable else { return nil }
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<URL, any Error>?, Never>) in
            if let videoResult {
                continuation.resume(returning: videoResult)
            } else {
                videoWaiters.append(continuation)
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(5))
                    guard let self else { return }
                    let pending = self.videoWaiters
                    self.videoWaiters = []
                    pending.forEach { $0.resume(returning: nil) }
                }
            }
        }
        camera.stop()
        return try? result?.get()
    }

    private func reset() {
        phase = .idle
        startedAt = nil
        drag = .zero
        audioURL = nil
        reachedCap = false
    }

    func teardown() {
        cancel()
        camera.stop()
    }

    /// Video notes are small: ~640×480 H.264 keeps a minute around 5–8 MB.
    private static func compress(_ source: URL) async -> URL? {
        let output = FileManager.default.temporaryDirectory.appending(path: "note-\(UUID().uuidString).mp4")
        guard let session = AVAssetExportSession(asset: AVURLAsset(url: source), presetName: AVAssetExportPreset640x480) else {
            return nil
        }
        session.shouldOptimizeForNetworkUse = true
        do {
            try await session.export(to: output, as: .mp4)
            try? FileManager.default.removeItem(at: source)
            return output
        } catch {
            return nil
        }
    }
}
