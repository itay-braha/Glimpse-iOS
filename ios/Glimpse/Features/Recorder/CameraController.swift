@preconcurrency import AVFoundation

/// Owns the capture session on a private serial queue. Recording is hard-capped
/// at 15 seconds by `maxRecordedDuration`.
final class CameraController: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    static let maxDuration: Double = 15

    /// Recording cap for this session (15s profile clips, shorter for verification selfies).
    let maxDuration: Double

    init(maxDuration: Double = CameraController.maxDuration) {
        self.maxDuration = maxDuration
        super.init()
    }

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.itaybraha.glimpse.camera")
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var position: AVCaptureDevice.Position = .front
    private let handlerLock = NSLock()
    private var finishHandler: (@Sendable (Result<URL, any Error>) -> Void)?

    static var isAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    static func requestAccess() async -> Bool {
        let video = await AVCaptureDevice.requestAccess(for: .video)
        let audio = await AVCaptureDevice.requestAccess(for: .audio)
        return video && audio
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            queue.async {
                do {
                    try self.configure()
                    self.session.startRunning()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func flip() {
        queue.async {
            guard !self.movieOutput.isRecording else { return }
            self.position = self.position == .front ? .back : .front
            try? self.configure()
        }
    }

    func startRecording(onFinish: @escaping @Sendable (Result<URL, any Error>) -> Void) {
        queue.async {
            guard !self.movieOutput.isRecording else { return }
            self.handlerLock.withLock { self.finishHandler = onFinish }
            let url = FileManager.default.temporaryDirectory.appending(path: "raw-\(UUID().uuidString).mov")
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() {
        queue.async {
            if self.movieOutput.isRecording { self.movieOutput.stopRecording() }
        }
    }

    // Runs on `queue`.
    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high

        if let videoInput { session.removeInput(videoInput) }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw GlimpseError.cameraUnavailable
        }
        let input = try AVCaptureDeviceInput(device: camera)
        if session.canAddInput(input) {
            session.addInput(input)
            videoInput = input
        }

        let hasAudio = session.inputs.contains { ($0 as? AVCaptureDeviceInput)?.device.hasMediaType(.audio) == true }
        if !hasAudio, let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic), session.canAddInput(micInput) {
            session.addInput(micInput)
        }

        if !session.outputs.contains(movieOutput), session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            movieOutput.maxRecordedDuration = CMTime(seconds: maxDuration, preferredTimescale: 600)
        }
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        let handler = handlerLock.withLock {
            defer { finishHandler = nil }
            return finishHandler
        }
        // Hitting the 15s cap reports an "error" even though the file is complete.
        let finishedCleanly = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? (error == nil)
        if finishedCleanly {
            handler?(.success(outputFileURL))
        } else {
            handler?(.failure(error ?? GlimpseError.cameraUnavailable))
        }
    }
}
