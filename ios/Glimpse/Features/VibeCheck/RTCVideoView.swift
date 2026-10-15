import SwiftUI
@preconcurrency import WebRTC

/// Metal-backed WebRTC renderer for SwiftUI.
struct RTCVideoView: UIViewRepresentable {
    var mirrored = false
    let attach: (RTCMTLVideoView) -> Void

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: .zero)
        view.videoContentMode = .scaleAspectFill
        view.clipsToBounds = true
        if mirrored {
            view.transform = CGAffineTransform(scaleX: -1, y: 1)
        }
        attach(view)
        return view
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {}
}
