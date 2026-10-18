import AVFoundation
@preconcurrency import WebRTC

/// The safety recording of one Vibe Check. Both people agree to it in the lobby.
///
/// Two recorders run on each phone:
/// - **own**: what this phone's camera and microphone send (~350 kbps video + voice);
/// - **received**: a low-quality, video-only copy of what the other phone sends
///   (~200 kbps), kept on the phone as a backup.
///
/// Both are written in 20-second pieces. Each own piece is uploaded to Glimpse's
/// private storage as soon as it closes, *during* the call, so closing or deleting
/// the app loses at most the last few seconds. The received copy is uploaded only
/// if the other person's own recording doesn't arrive (or the call is reported),
/// so storage isn't doubled. Everything is kept 30 days and opened only for a report.
///
/// Files live in Application Support, excluded from backups and protected while
/// the phone is locked.
final class VibeSafetyRecorder: @unchecked Sendable {
    enum Stream: String, Codable, Sendable {
        case own
        case received
    }

    /// One closed piece, ready to upload.
    struct Segment: Sendable {
        let url: URL
        let part: Int
        let startedAt: Date
        let duration: Double
        let stream: Stream
    }

    static let segmentSeconds: Double = 20

    let stream: Stream
    private(set) var startedAt = Date.now
    private let onSegment: @Sendable (Segment) -> Void
    private let bitrate: Int
    private let queue: DispatchQueue
    private let folder = VibeSafetyRecorder.directory

    private var current: OpenSegment?
    private var part = 0
    private var isFinished = false
    private var closing: [Task<Void, Never>] = []

    init(stream: Stream, onSegment: @escaping @Sendable (Segment) -> Void) {
        self.stream = stream
        self.onSegment = onSegment
        bitrate = stream == .own ? 350_000 : 200_000
        queue = DispatchQueue(label: "glimpse.vibe.recorder.\(stream.rawValue)")
    }

    /// Where pieces wait for upload.
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

    func start() {
        startedAt = .now
    }

    /// Every frame of this recorder's stream (camera frames for own, decoded remote frames for received).
    func append(_ frame: RTCVideoFrame) {
        // Hardware-decoded and camera frames are pixel buffers; anything else is skipped.
        guard let pixels = (frame.buffer as? RTCCVPixelBuffer)?.pixelBuffer else { return }
        // CVPixelBuffer isn't Sendable; WebRTC doesn't reuse it while we hold it.
        nonisolated(unsafe) let buffer = pixels
        let time = CMTime(value: frame.timeStampNs, timescale: 1_000_000_000)
        let rotation = frame.rotation
        queue.async { [self] in
            guard !isFinished else { return }
            if let open = current, (time - open.firstTime).seconds >= Self.segmentSeconds {
                close(open)
                current = nil
            }
            if current == nil {
                current = openSegment(for: buffer, rotation: rotation, at: time)
            }
            guard let open = current else { return }
            if open.input.isReadyForMoreMediaData {
                _ = open.adaptor.append(buffer, withPresentationTime: time)
                current?.lastTime = time
            }
        }
    }

    /// Closes the last piece and waits until every piece has been handed over.
    func finish() async {
        let pending = queue.sync { () -> [Task<Void, Never>] in
            isFinished = true
            if let open = current {
                close(open)
                current = nil
            }
            return closing
        }
        for task in pending { await task.value }
    }

    // MARK: Pieces

    /// AVFoundation objects for one piece. Only touched on `queue` until closed.
    private struct OpenSegment: @unchecked Sendable {
        let writer: AVAssetWriter
        let input: AVAssetWriterInput
        let adaptor: AVAssetWriterInputPixelBufferAdaptor
        let audio: AVAudioRecorder?
        let videoURL: URL
        let audioURL: URL?
        let part: Int
        let wallStart: Date
        let firstTime: CMTime
        var lastTime: CMTime
    }

    private func openSegment(for buffer: CVPixelBuffer, rotation: RTCVideoRotation, at time: CMTime) -> OpenSegment? {
        let id = UUID().uuidString.lowercased()
        let videoURL = folder.appending(path: "piece-\(id).mp4")
        guard let writer = try? AVAssetWriter(outputURL: videoURL, fileType: .mp4) else { return nil }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: CVPixelBufferGetWidth(buffer),
            AVVideoHeightKey: CVPixelBufferGetHeight(buffer),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate],
        ])
        input.expectsMediaDataInRealTime = true
        input.transform = CGAffineTransform(rotationAngle: CGFloat(rotation.rawValue) * .pi / 180)
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: time)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)

        var audio: AVAudioRecorder?
        var audioURL: URL?
        if stream == .own {
            let url = folder.appending(path: "piece-\(id).m4a")
            audio = try? AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 22_050,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32_000,
            ])
            audio?.record()
            audioURL = url
        }

        defer { part += 1 }
        return OpenSegment(
            writer: writer, input: input, adaptor: adaptor, audio: audio,
            videoURL: videoURL, audioURL: audioURL, part: part,
            wallStart: .now, firstTime: time, lastTime: time
        )
    }

    /// Finishes a piece off the recording queue and hands it over.
    private func close(_ open: OpenSegment) {
        open.audio?.stop()
        let stream = stream
        let folder = folder
        let onSegment = onSegment
        closing.append(Task.detached {
            open.input.markAsFinished()
            await open.writer.finishWriting()
            guard open.writer.status == .completed else {
                if let audioURL = open.audioURL { try? FileManager.default.removeItem(at: audioURL) }
                return
            }
            let output = folder.appending(path: "vibe-\(UUID().uuidString.lowercased()).mp4")
            var url = open.videoURL
            if let audioURL = open.audioURL {
                if await VibeSafetyRecorder.join(video: open.videoURL, audio: audioURL, into: output) {
                    try? FileManager.default.removeItem(at: open.videoURL)
                    url = output
                }
                try? FileManager.default.removeItem(at: audioURL)
            } else if (try? FileManager.default.moveItem(at: open.videoURL, to: output)) != nil {
                url = output
            }
            onSegment(Segment(
                url: url, part: open.part, startedAt: open.wallStart,
                duration: max((open.lastTime - open.firstTime).seconds, 0), stream: stream
            ))
        })
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

/// Pieces waiting to upload. Survives the app being closed: the next launch
/// retries, and files are removed only once the server has them.
/// Own pieces always go up. A received (backup) piece goes up only when the
/// server says the other person's own recording is missing or the call was
/// reported; it's dropped once theirs is safely in.
@MainActor
enum VibeRecordingUploads {
    private struct Pending: Codable {
        let matchID: UUID
        let file: String
        let startedAt: Date
        var part: Int?
        var duration: Double?
        var stream: VibeSafetyRecorder.Stream?
        var callID: UUID?
    }

    private static let key = "glimpse.vibeUploads"
    private static var isUploading = false

    static func enqueue(_ segment: VibeSafetyRecorder.Segment, matchID: UUID, callID: UUID? = nil) {
        var pending = load()
        pending.append(Pending(
            matchID: matchID, file: segment.url.lastPathComponent, startedAt: segment.startedAt,
            part: segment.part, duration: segment.duration, stream: segment.stream, callID: callID
        ))
        save(pending)
    }

    static func uploadPending(using backend: any GlimpseBackend) async {
        guard !isUploading else { return }
        isUploading = true
        defer { isUploading = false }

        var decisions: [String: VibeBackupDecision] = [:]
        var done: Set<String> = []
        for item in load() {
            let url = VibeSafetyRecorder.directory.appending(path: item.file)
            guard FileManager.default.fileExists(atPath: url.path()) else {
                done.insert(item.file)
                continue
            }
            let received = item.stream == .received
            if received {
                let key = item.callID?.uuidString ?? item.matchID.uuidString
                if decisions[key] == nil {
                    decisions[key] = (try? await backend.vibeBackupDecision(matchID: item.matchID, callID: item.callID)) ?? .wait
                }
                switch decisions[key] ?? .wait {
                case .discard:
                    try? FileManager.default.removeItem(at: url)
                    done.insert(item.file)
                    continue
                case .wait:
                    if Date.now.timeIntervalSince(item.startedAt) > 7 * 86_400 {
                        try? FileManager.default.removeItem(at: url)
                        done.insert(item.file)
                    }
                    continue
                case .upload:
                    break
                }
            }
            do {
                try await backend.uploadVibeSegment(
                    matchID: item.matchID, callID: item.callID, fileURL: url, startedAt: item.startedAt,
                    part: item.part ?? 0, duration: item.duration, received: received
                )
                try? FileManager.default.removeItem(at: url)
                done.insert(item.file)
            } catch {
                // Expired on the server after 30 days anyway; give up locally after a week.
                if Date.now.timeIntervalSince(item.startedAt) > 7 * 86_400 {
                    try? FileManager.default.removeItem(at: url)
                    done.insert(item.file)
                }
            }
        }
        // Re-read: pieces may have been enqueued while this pass was uploading.
        save(load().filter { !done.contains($0.file) })
    }

    private static func load() -> [Pending] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Pending].self, from: data)) ?? []
    }

    private static func save(_ pending: [Pending]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(pending), forKey: key)
    }
}
