import SwiftUI

struct VibeCallView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var model: VibeCallModel
    @State private var showSurvey = false
    @State private var reportAfterEnd = false

    /// Called after the survey with the chosen outcome.
    let onFinished: (VibeOutcome?) -> Void

    init(match: MatchSummary, myID: UUID, backend: any GlimpseBackend, onFinished: @escaping (VibeOutcome?) -> Void) {
        _model = State(initialValue: VibeCallModel(match: match, myID: myID, backend: backend))
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch model.phase {
            case .preparing:
                ProgressView().tint(.white)
            case let .failed(message):
                failure(message)
            case .lobby, .connecting:
                lobby
            case .live:
                live
            case .ended:
                if showSurvey {
                    VibeSurveyView(name: model.match.displayName, startReport: reportAfterEnd) { outcome in
                        onFinished(outcome)
                        dismiss()
                    }
                } else {
                    ProgressView().tint(.white)
                        .task { showSurvey = true }
                }
            }
        }
        .statusBarHidden(model.phase == .live)
        .task { await model.prepare() }
        .onDisappear { model.end() }
        .sensoryFeedback(.warning, trigger: model.thirtySecondWarning)
    }

    // MARK: Lobby

    private var lobby: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Leave", systemImage: "xmark") {
                    model.end()
                    onFinished(nil)
                    dismiss()
                }
                .labelStyle(.iconOnly)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: .circle)
                Spacer()
            }

            Text("3-Minute Vibe Check")
                .font(.glimpseTitle2)
                .foregroundStyle(Palette.brandGradient)
            Text("Check your camera and light. The call starts when you're both ready, and ends on its own after 3 minutes.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)

            localPreview
                .frame(maxWidth: .infinity)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.stroke))

            HStack(spacing: 18) {
                ReadyChip(name: "You", ready: model.meReady)
                ReadyChip(name: model.match.displayName, ready: model.otherReady)
            }

            Spacer(minLength: 0)

            SafetyNotice(isProtected: model.captureProtected, agreed: $model.agreedToSafetyRecording)
                .disabled(model.meReady)

            Button {
                model.markReady()
            } label: {
                if model.phase == .connecting {
                    HStack(spacing: 10) {
                        ProgressView().tint(Palette.onMint)
                        Text("Connecting…")
                    }
                } else {
                    Text(model.meReady ? "Waiting for \(model.match.displayName)…" : "I'm ready")
                        .accessibilityIdentifier("vibe.ready")
                }
            }
            .buttonStyle(.glimpse)
            .disabled(model.meReady || !model.agreedToSafetyRecording)
        }
        .padding(20)
    }

    @ViewBuilder
    private var localPreview: some View {
        if let client = model.client {
            RTCVideoView(mirrored: true) { client.renderLocal(to: $0) }
        } else {
            CaptureProtected {
                demoLocalPreview
            }
        }
    }

    private var demoLocalPreview: some View {
        Group {
            ZStack {
                Palette.seededGradient(app.profile?.displayName ?? "You")
                VStack(spacing: 8) {
                    Image(systemName: "video.fill").font(.largeTitle)
                    Text(model.isDemo ? "Demo: your camera preview appears here" : "Starting camera…")
                        .font(.footnote)
                }
                .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    // MARK: Live

    private var live: some View {
        ZStack {
            remoteVideo
                .ignoresSafeArea()
                .overlay {
                    if model.localCaptureActive || model.remoteCaptureActive {
                        captureShield
                    }
                }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text(model.clockText)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(model.secondsLeft <= 30 ? Palette.pink : .white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: .capsule)
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("\(model.secondsLeft) seconds left")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                HStack {
                    Spacer()
                    Button {
                        reportAfterEnd = true
                        model.end()
                    } label: {
                        Label("End now & report", systemImage: "exclamationmark.octagon.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.red, in: .capsule)
                    }
                    .accessibilityLabel("End now and report")
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                Spacer()

                HStack(alignment: .bottom) {
                    if let client = model.client {
                        RTCVideoView(mirrored: true) { client.renderLocal(to: $0) }
                            .frame(width: 110, height: 150)
                            .clipShape(.rect(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.3)))
                    }
                    Spacer()
                    Button("Hang up", systemImage: "phone.down.fill") { model.end() }
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.red, in: .circle)
                }
                .padding(.horizontal, 16)

                if model.showTopics {
                    IcebreakerCard(
                        text: model.currentTopic,
                        onNext: { model.nextTopic() },
                        onHide: { model.setShowTopics(false) }
                    )
                    .padding(16)
                } else {
                    Button("Topics", systemImage: "sparkles") { model.setShowTopics(true) }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: .capsule)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .accessibilityIdentifier("vibe.showTopics")
                }
            }
        }
    }

    @ViewBuilder
    private var remoteVideo: some View {
        if let client = model.client {
            RTCVideoView { client.renderRemote(to: $0) }
        } else {
            CaptureProtected {
                demoRemoteVideo
            }
        }
    }

    private var demoRemoteVideo: some View {
        Group {
            ZStack {
                Palette.seededGradient(model.match.displayName)
                Text(String(model.match.displayName.prefix(1)))
                    .font(.system(size: 160, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.15))
                Text("Demo call with \(model.match.displayName)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                    .offset(y: 120)
            }
        }
    }

    private var captureShield: some View {
        ZStack {
            Color.black
            VStack(spacing: 10) {
                Image(systemName: "eye.slash.fill").font(.largeTitle)
                Text(model.localCaptureActive
                     ? "Video is hidden while your screen is being recorded."
                     : "\(model.match.displayName)'s screen is being captured. Your video is paused.")
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(32)
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash.fill").font(.largeTitle).foregroundStyle(Palette.textTertiary)
            Text(message).multilineTextAlignment(.center).foregroundStyle(Palette.textSecondary)
            Button("Close") {
                onFinished(nil)
                dismiss()
            }
            .buttonStyle(.glimpseSecondary)
        }
        .padding(32)
    }
}

private struct ReadyChip: View {
    let name: String
    let ready: Bool

    var body: some View {
        Label(LocalizedStringKey(name), systemImage: ready ? "checkmark.circle.fill" : "circle.dotted")
            .font(.glimpseCaption)
            .foregroundStyle(ready ? Palette.mint : Palette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.surfaceRaised, in: .capsule)
            .accessibilityLabel("\(name) \(ready ? "ready" : "not ready yet")")
    }
}

/// A topic to talk about. Tap anywhere for a new one; × hides topics (remembered).
private struct IcebreakerCard: View {
    let text: String
    let onNext: () -> Void
    let onHide: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onNext) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles").foregroundStyle(Palette.brandGradient)
                    Text(text)
                        .font(.glimpseHeadline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .contentTransition(.opacity)
                    Spacer(minLength: 4)
                    Label("New topic", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows another topic")
            .accessibilityIdentifier("vibe.nextTopic")
            Button("Hide topics", systemImage: "xmark", action: onHide)
                .labelStyle(.iconOnly)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 28, height: 28)
                .accessibilityIdentifier("vibe.hideTopics")
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .animation(.snappy, value: text)
    }
}

/// The lobby's promise and consent: nothing can be captured, and a private
/// safety recording exists only for reports.
private struct SafetyNotice: View {
    let isProtected: Bool
    @Binding var agreed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                isProtected
                    ? "Screenshots and screen recording are blocked and not allowed in Vibe Checks. They come out black, and an attempt is shown to both of you and noted for our safety team."
                    : "Screenshots and screen recording are not allowed in Vibe Checks. An attempt pauses your video, is shown to both of you and is noted for our safety team.",
                systemImage: "eye.slash.fill"
            )
            .accessibilityIdentifier(isProtected ? "vibe.captureProtected" : "vibe.captureDetected")
            Label(
                "For safety, the call is recorded privately and stored by Glimpse for 30 days, even if someone deletes the app. Nobody watches it unless one of you reports this call, and then only Glimpse's safety team.",
                systemImage: "lock.shield.fill"
            )
            Toggle("I agree", isOn: $agreed)
                .tint(Palette.mint)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("vibe.agree")
        }
        .font(.footnote)
        .foregroundStyle(Palette.textSecondary)
        .padding(14)
        .background(Palette.surface, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.stroke))
    }
}
