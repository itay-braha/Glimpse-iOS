import SwiftUI
import UIKit

/// A view whose contents iOS leaves out of screenshots, screen recordings,
/// AirPlay and mirroring: they come out black.
///
/// iOS has no public "block screenshots" switch, but the text layer of a secure
/// (password) field is excluded from every capture by the system. Hosting the
/// call's video inside that layer gives the same protection to the video. This
/// is the long-standing technique secure-messaging and banking apps use. If a
/// future iOS changes the field's internals, `isProtected` turns false and the
/// call still runs with detection (capture flags + paused camera) only.
final class SecureCanvas: UIView {
    /// Put the protected content here.
    let contentView: UIView
    /// True when the system's capture exclusion is in place.
    let isProtected: Bool

    private let field = UITextField()

    /// Whether profile videos and video notes are also kept out of captures. Off:
    /// screenshots are allowed there, and screen recording is blocked app-wide by
    /// `ScreenRecordingShield`. Vibe Check calls always use the protected layer.
    static var protectsMedia: Bool { false }

    override convenience init(frame: CGRect) {
        self.init(frame: frame, protect: true)
    }

    init(frame: CGRect, protect: Bool) {
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false
        let canvas = protect ? field.layer.sublayers?.first?.delegate as? UIView : nil
        isProtected = canvas != nil
        contentView = canvas ?? UIView()
        super.init(frame: frame)

        backgroundColor = .black
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.isUserInteractionEnabled = true
        contentView.backgroundColor = .black
        contentView.frame = bounds
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(contentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Adds a view that fills the protected area.
    func embed(_ view: UIView) {
        view.frame = contentView.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(view)
    }
}

/// SwiftUI content kept out of screenshots and screen recordings (see `SecureCanvas`).
struct CaptureProtected<Content: View>: UIViewRepresentable {
    @ViewBuilder let content: Content

    func makeUIView(context: Context) -> SecureCanvas {
        let canvas = SecureCanvas(frame: .zero)
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        canvas.embed(host.view)
        context.coordinator.host = host
        return canvas
    }

    func updateUIView(_ uiView: SecureCanvas, context: Context) {
        context.coordinator.host?.rootView = content
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        var host: UIHostingController<Content>?
    }
}
