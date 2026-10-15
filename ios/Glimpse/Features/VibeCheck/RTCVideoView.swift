import SwiftUI
@preconcurrency import WebRTC

/// Metal-backed WebRTC renderer for SwiftUI, inside a `SecureCanvas` so
/// screenshots and screen recordings of a Vibe Check show black, not a person.
struct RTCVideoView: UIViewRepresentable {
    var mirrored = false
    let attach: (RTCMTLVideoView) -> Void

    func makeUIView(context: Context) -> SecureCanvas {
        let canvas = SecureCanvas(frame: .zero)
        let video = RTCMTLVideoView(frame: .zero)
        video.videoContentMode = .scaleAspectFill
        video.clipsToBounds = true
        if mirrored {
            video.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
        canvas.embed(video)
        attach(video)
        return canvas
    }

    func updateUIView(_ uiView: SecureCanvas, context: Context) {}
}
