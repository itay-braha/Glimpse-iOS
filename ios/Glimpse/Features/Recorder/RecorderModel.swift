import Foundation
import Observation

/// What the recording is for: a profile moment or a verification selfie.
enum RecordingPurpose: Equatable {
    case profileClip
    case verification(VerificationChallenge)

    var maxDuration: Double {
        switch self {
        case .profileClip: CameraController.maxDuration
        case .verification: 5
        }
    }

    var prompt: String {
        switch self {
        case .profileClip: String(localized: "Aim for 7 seconds (up to 15). Be yourself.")
        case let .verification(challenge): challenge.gesture
        }
    }

    var usesFrontCameraOnly: Bool {
        if case .verification = self { return true }
        return false
    }
}

@MainActor
@Observable
final class RecorderModel {
    enum State: Equatable {
        case preparing
        case unavailable(String)
        case ready
        case recording(startedAt: Date)
        case review(URL)
        case uploading
    }

    private(set) var state: State = .preparing
    var errorMessage: String?
    /// Vibe prompt chosen in review (profile clips only).
    var selectedPrompt: VibePrompt?
    let purpose: RecordingPurpose
    let camera: CameraController

    init(purpose: RecordingPurpose = .profileClip) {
        self.purpose = purpose
        camera = CameraController(maxDuration: purpose.maxDuration)
    }

    func prepare() async {
        guard CameraController.isAvailable else {
            state = .unavailable(String(localized: "This device has no camera. On a real iPhone you can record up to 15 seconds here."))
            return
        }
        guard await CameraController.requestAccess() else {
            state = .unavailable(String(localized: "Glimpse needs camera and microphone access to record. You can turn it on in Settings."))
            return
        }
        do {
            try await camera.start()
            state = .ready
        } catch {
            state = .unavailable(GlimpseError.describe(error))
        }
    }

    func toggleRecording() {
        switch state {
        case .ready:
            state = .recording(startedAt: .now)
            camera.startRecording { [weak self] result in
                Task { @MainActor in self?.finished(result) }
            }
        case .recording:
            camera.stopRecording()
        default:
            break
        }
    }

    func retake() {
        state = .ready
    }

    func flip() {
        camera.flip()
    }

    func teardown() {
        camera.stop()
    }

    /// Compresses and uploads the reviewed clip. Returns true on success; the
    /// new profile video (if any) is passed back for profile clips.
    func upload(using backend: any GlimpseBackend) async -> (succeeded: Bool, video: ProfileVideo?) {
        guard case let .review(url) = state else { return (false, nil) }
        state = .uploading
        do {
            if case .profileClip = purpose, try await SensitiveContentChecker.shared.isSensitive(url) {
                errorMessage = String(localized: "This video looks like it may contain nudity, which isn't allowed on Glimpse.")
                state = .review(url)
                return (false, nil)
            }
            var clip = try await VideoCompressor.prepare(url)
            clip.promptKey = selectedPrompt?.rawValue
            switch purpose {
            case .profileClip:
                return (true, try await backend.uploadClip(clip))
            case let .verification(challenge):
                try await backend.submitVerification(challenge, clip: clip)
                return (true, nil)
            }
        } catch {
            errorMessage = GlimpseError.describe(error)
            state = .review(url)
            return (false, nil)
        }
    }

    /// Demo builds without a camera can still exercise the flow with a sample clip.
    func useSampleClip(using backend: any GlimpseBackend) async -> (succeeded: Bool, video: ProfileVideo?) {
        guard let url = URL(string: DemoData.clipURLs[0]) else { return (false, nil) }
        state = .uploading
        let clip = RecordedClip(
            fileURL: url, durationSeconds: purpose.maxDuration, thumbnailJPEG: nil, promptKey: selectedPrompt?.rawValue
        )
        switch purpose {
        case .profileClip:
            let video = try? await backend.uploadClip(clip)
            return (video != nil, video)
        case let .verification(challenge):
            let submitted = (try? await backend.submitVerification(challenge, clip: clip)) != nil
            return (submitted, nil)
        }
    }

    private func finished(_ result: Result<URL, any Error>) {
        switch result {
        case let .success(url):
            state = .review(url)
        case let .failure(error):
            errorMessage = GlimpseError.describe(error)
            state = .ready
        }
    }
}
