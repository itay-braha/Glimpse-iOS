import AVFoundation
@preconcurrency import WebRTC

/// The safety recording of one Vibe Check: what *this* phone's camera and
/// microphone sent, nothing else. Both people agree to it in the lobby. After
/// the call it's uploaded to a private bucket where it's kept for 30 days and only
/// opened by the safety team if either person reports the call.
///
/// Video comes straight from the camera frames WebRTC sends (H.264, ~700 kbps);
/// audio from the microphone alongside the call. The two are joined into one mp4
/// when the call ends. Files live in Application Support, excluded from backups
/// and protected while the phone is locked.
final class VibeSafetyRecorder: @unchecked Sendable {
    private let queue = DispatchQueue(label: "glimpse.vibe.recorder")
    private let folder: URL
    private let videoURL: URL
    private let audioURL: URL
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audio: AVAudioRecorder?
    private var sessionStarted = false
    private var isFinished = false
    private(set) var startedAt = Date.now

    init() {
        folder = Self.directory
        let id = UUID().uuidString.lowercased()
        videoURL = folder.appending(path: "video-\(id).mp4")
        audioURL = folder.appending(path: "audio-\(id).m4a")
    }

    /// Where finished recordings wait for upload.
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var folder = base.appending(path: "VibeSafety", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? folder.setResourceValues(values)
        return folder
    }

    /// Starts the microphone side; video starts with the first camera frame.
    func start() {
        startedAt = .now
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
        ]
        let recorder = try? AVAudioRecorder(url: audioURL, settings: settings)
        recorder?.record()
        queue.sync { audio = recorder }
    }

    /// Called for every frame this phone's camera sends into the call.
    func append(_ frame: RTCVideoFrame) {
        guard let pixels = (frame.buffer as? RTCCVPixelBuffer)?.pixelBuffer else { return }
        // CVPixelBuffer isn't Sendable; WebRTC hands it over and doesn't reuse it while we hold it.
        nonisolated(unsafe) let buffer = pixels
        let time = CMTime(value: frame.timeStampNs, timescale: 1_000_000_000)
        let rotation = frame.rotation
        queue.async { [self] in
            guard !isFinished else { return }
            if writer == nil { setUpWriter(for: buffer, rotation: rotation) }
            guard let writer, let input, let adaptor else { return }
            if !sessionStarted {
                writer.startSession(atSourceTime: time)
                sessionStarted = true
            }
            if input.isReadyForMoreMediaData {
                _ = adaptor.append(buffer, withPresentationTime: time)
            }
        }
    }

    /// Stops recording and returns one mp4 (video + audio), or nil if nothing was captured.
    func finish() async -> URL? {
        let (writer, input, audio, started) = queue.sync { () -> (AVAssetWriter?, AVAssetWriterInput?, AVAudioRecorder?, Bool) in
            isFinished = true
            return (self.writer, self.input, self.audio, self.sessionStarted)
        }
        audio?.stop()
        guard let writer, started else {
            try? FileManager.default.removeItem(at: audioURL)
            return nil
        }
        input?.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { return nil }
        let output = folder.appending(path: "vibe-\(UUID().uuidString.lowercased()).mp4")
        let joined = await Self.join(video: videoURL, audio: audioURL, into: output)
        try? FileManager.default.removeItem(at: audioURL)
        if joined {
            try? FileManager.default.removeItem(at: videoURL)
            return output
        }
        return videoURL // video alone is still evidence
    }

    private func setUpWriter(for buffer: CVPixelBuffer, rotation: RTCVideoRotation) {
        guard let writer = try? AVAssetWriter(outputURL: videoURL, fileType: .mp4) else { return }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: CVPixelBufferGetWidth(buffer),
            AVVideoHeightKey: CVPixelBufferGetHeight(buffer),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 700_000],
        ])
        input.expectsMediaDataInRealTime = true
        input.transform = CGAffineTransform(rotationAngle: CGFloat(rotation.rawValue) * .pi / 180)
        guard writer.canAdd(input) else { return }
        writer.add(input)
        guard writer.startWriting() else { return }
        self.writer = writer
        self.input = input
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
    }

    private static func join(video: URL, audio: URL, into output: URL) async -> Bool {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        let audioAsset = AVURLAsset(url: audio)
        guard let sourceVideo = try? await videoAsset.loadTracks(withMediaType: .video).first,
              let duration = try? await videoAsset.load(.duration),
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { return false }
        try? videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceVideo, at: .zero)
        if let transform = try? await sourceVideo.load(.preferredTransform) {
            videoTrack.preferredTransform = transform
        }
        if let sourceAudio = try? await audioAsset.loadTracks(withMediaType: .audio).first,
           let audioDuration = try? await audioAsset.load(.duration),
           let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let span = CMTimeMinimum(duration, audioDuration)
            try? audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: span), of: sourceAudio, at: .zero)
        }
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            return false
        }
        do {
            try await export.export(to: output, as: .mp4)
            return true
        } catch {
            return false
        }
    }
}

/// Finished recordings waiting to upload. Survives the app being closed: the next
/// launch retries, and files are removed only once the server has them.
@MainActor
enum VibeRecordingUploads {
    private struct Pending: Codable {
        let matchID: UUID
        let file: String
        let startedAt: Date
    }

    private static let key = "glimpse.vibeUploads"

    static func enqueue(_ url: URL, matchID: UUID, startedAt: Date) {
        var pending = load()
        pending.append(Pending(matchID: matchID, file: url.lastPathComponent, startedAt: startedAt))
        save(pending)
    }

    static func uploadPending(using backend: any GlimpseBackend) async {
        var remaining: [Pending] = []
        for item in load() {
            let url = VibeSafetyRecorder.directory.appending(path: item.file)
            guard FileManager.default.fileExists(atPath: url.path()) else { continue }
            do {
                try await backend.uploadVibeRecording(matchID: item.matchID, fileURL: url, startedAt: item.startedAt)
                try? FileManager.default.removeItem(at: url)
            } catch {
                // Expired on the server side after 30 days anyway; give up locally after a week.
                if Date.now.timeIntervalSince(item.startedAt) < 7 * 86_400 {
                    remaining.append(item)
                } else {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        save(remaining)
    }

    private static func load() -> [Pending] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Pending].self, from: data)) ?? []
    }

    private static func save(_ pending: [Pending]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(pending), forKey: key)
    }
}
