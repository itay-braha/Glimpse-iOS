import AVFoundation
@preconcurrency import WebRTC

/// One peer-to-peer audio/video connection for a Vibe Check.
/// WebRTC calls the delegate on its own signaling thread; everything that
/// leaves this class goes through @Sendable callbacks with plain values.
final class WebRTCClient: NSObject, RTCPeerConnectionDelegate, @unchecked Sendable {
    nonisolated(unsafe) private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory()
        )
    }()

    var onLocalCandidate: (@Sendable (_ sdp: String, _ mLineIndex: Int32, _ mid: String?) -> Void)?
    var onConnectionChange: (@Sendable (_ connected: Bool) -> Void)?
    var onRemoteVideo: (@Sendable () -> Void)?
    /// Every frame our camera sends into the call (for the safety recording).
    var onLocalFrame: (@Sendable (RTCVideoFrame) -> Void)? {
        get { frameTap.onFrame }
        set { frameTap.onFrame = newValue }
    }
    /// Every decoded frame the other phone sends (for the backup safety copy).
    var onRemoteFrame: (@Sendable (RTCVideoFrame) -> Void)? {
        get { remoteTap.onFrame }
        set { remoteTap.onFrame = newValue }
    }

    private let peerConnection: RTCPeerConnection
    private let capturer: RTCCameraVideoCapturer
    private let frameTap: FrameTap
    private let remoteTap = RemoteFrameTap()
    private let localVideoTrack: RTCVideoTrack
    private let localAudioTrack: RTCAudioTrack
    private var remoteVideoTrack: RTCVideoTrack?
    private var pendingRemoteRenderer: RTCVideoRenderer?
    private let lock = NSLock()

    private let mediaConstraints = RTCMediaConstraints(
        mandatoryConstraints: [
            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue,
        ],
        optionalConstraints: nil
    )

    init?(iceServers: [IceServerConfig]) {
        let config = RTCConfiguration()
        config.iceServers = iceServers.map {
            RTCIceServer(urlStrings: $0.urls, username: $0.username, credential: $0.credential)
        }
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
        )
        let connection: RTCPeerConnection? = Self.factory.peerConnection(
            with: config, constraints: constraints, delegate: nil
        )
        guard let connection else { return nil }
        peerConnection = connection

        let audioSource = Self.factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        localAudioTrack = Self.factory.audioTrack(with: audioSource, trackId: "glimpse-audio")
        let videoSource = Self.factory.videoSource()
        frameTap = FrameTap(source: videoSource)
        capturer = RTCCameraVideoCapturer(delegate: frameTap)
        localVideoTrack = Self.factory.videoTrack(with: videoSource, trackId: "glimpse-video")

        super.init()
        peerConnection.delegate = self
        _ = peerConnection.add(localAudioTrack, streamIds: ["glimpse"])
        _ = peerConnection.add(localVideoTrack, streamIds: ["glimpse"])
    }

    // MARK: Media

    func startCapture() {
        let devices = RTCCameraVideoCapturer.captureDevices()
        guard let device = devices.first(where: { $0.position == .front }) ?? devices.first else { return }
        let formats = RTCCameraVideoCapturer.supportedFormats(for: device)
        // ~640px wide keeps a 3-minute call light on cellular.
        let format = formats.min { lhs, rhs in
            abs(CMVideoFormatDescriptionGetDimensions(lhs.formatDescription).width - 640)
                < abs(CMVideoFormatDescriptionGetDimensions(rhs.formatDescription).width - 640)
        }
        guard let format else { return }
        let maxFPS = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 30
        capturer.startCapture(with: device, format: format, fps: Int(min(maxFPS, 30)))
    }

    func renderLocal(to renderer: RTCVideoRenderer) {
        localVideoTrack.add(renderer)
    }

    func renderRemote(to renderer: RTCVideoRenderer) {
        lock.withLock {
            if let remoteVideoTrack {
                remoteVideoTrack.add(renderer)
            } else {
                pendingRemoteRenderer = renderer
            }
        }
    }

    /// Stops sending our camera (used while the other side is screen recording).
    func setVideoEnabled(_ enabled: Bool) {
        localVideoTrack.isEnabled = enabled
    }

    func close() {
        capturer.stopCapture()
        peerConnection.close()
    }

    // MARK: Signaling

    func makeOffer(completion: @escaping @Sendable (String?) -> Void) {
        peerConnection.offer(for: mediaConstraints) { [weak self] description, _ in
            guard let self, let description else {
                completion(nil)
                return
            }
            let sdp = description.sdp
            self.peerConnection.setLocalDescription(description) { error in
                completion(error == nil ? sdp : nil)
            }
        }
    }

    func handleRemoteOffer(_ sdp: String, completion: @escaping @Sendable (String?) -> Void) {
        let offer = RTCSessionDescription(type: .offer, sdp: sdp)
        peerConnection.setRemoteDescription(offer) { [weak self] error in
            guard let self, error == nil else {
                completion(nil)
                return
            }
            self.peerConnection.answer(for: self.mediaConstraints) { description, _ in
                guard let description else {
                    completion(nil)
                    return
                }
                let answerSDP = description.sdp
                self.peerConnection.setLocalDescription(description) { error in
                    completion(error == nil ? answerSDP : nil)
                }
            }
        }
    }

    func handleRemoteAnswer(_ sdp: String) {
        peerConnection.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: sdp)) { _ in }
    }

    func addRemoteCandidate(sdp: String, mLineIndex: Int32, mid: String?) {
        let candidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: mLineIndex, sdpMid: mid)
        peerConnection.add(candidate) { _ in }
    }

    private func adoptRemoteTrack(_ track: RTCVideoTrack) {
        let renderer: RTCVideoRenderer? = lock.withLock {
            guard remoteVideoTrack == nil else { return nil }
            remoteVideoTrack = track
            defer { pendingRemoteRenderer = nil }
            return pendingRemoteRenderer
        }
        if let renderer {
            track.add(renderer)
        }
        track.add(remoteTap)
        onRemoteVideo?()
    }

    // MARK: RTCPeerConnectionDelegate

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if let track = stream.videoTracks.first {
            adoptRemoteTrack(track)
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        switch newState {
        case .connected, .completed:
            onConnectionChange?(true)
        case .failed, .closed:
            onConnectionChange?(false)
        default:
            break
        }
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        onLocalCandidate?(candidate.sdp, candidate.sdpMLineIndex, candidate.sdpMid)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didStartReceivingOn transceiver: RTCRtpTransceiver) {
        if let track = transceiver.receiver.track as? RTCVideoTrack {
            adoptRemoteTrack(track)
        }
    }
}

/// Receives the other phone's decoded frames for the backup safety copy.
private final class RemoteFrameTap: NSObject, RTCVideoRenderer, @unchecked Sendable {
    var onFrame: (@Sendable (RTCVideoFrame) -> Void)?

    func setSize(_ size: CGSize) {}

    func renderFrame(_ frame: RTCVideoFrame?) {
        if let frame { onFrame?(frame) }
    }
}

/// Passes camera frames to WebRTC and, alongside, to the safety recorder.
private final class FrameTap: NSObject, RTCVideoCapturerDelegate, @unchecked Sendable {
    let source: RTCVideoSource
    var onFrame: (@Sendable (RTCVideoFrame) -> Void)?

    init(source: RTCVideoSource) {
        self.source = source
    }

    func capturer(_ capturer: RTCVideoCapturer, didCapture frame: RTCVideoFrame) {
        source.capturer(capturer, didCapture: frame)
        onFrame?(frame)
    }
}
