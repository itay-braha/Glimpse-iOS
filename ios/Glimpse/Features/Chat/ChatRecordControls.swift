import SwiftUI

/// The mic / camera button beside the message field. Hold to record, release to
/// send, slide left to cancel, slide up to lock (hands-free). VoiceOver: a double
/// tap starts a locked recording, so no holding is needed.
struct ChatRecordButton: View {
    let kind: MessageKind
    let recorder: ChatMediaRecorder
    let onSend: (ChatMediaRecorder.Recording) -> Void

    @State private var pressing = false
    @State private var startTrigger = 0

    private var isActive: Bool { recorder.isRecording && recorder.kind == kind }

    var body: some View {
        Image(systemName: kind == .voice ? "mic.fill" : "video.circle.fill")
            .font(.system(size: kind == .voice ? 18 : 22, weight: .bold))
            .foregroundStyle(isActive ? .white : Palette.textPrimary)
            .frame(width: 44, height: 44)
            .background(isActive ? Palette.pink : Palette.surfaceRaised, in: .circle)
            .scaleEffect(isActive && recorder.phase == .holding ? 1.25 : 1)
            .animation(.snappy, value: recorder.phase)
            .opacity(recorder.isRecording && !isActive ? 0.3 : 1)
            .contentShape(.circle)
            .gesture(hold)
            .sensoryFeedback(.impact(weight: .medium), trigger: startTrigger)
            .accessibilityElement()
            .accessibilityLabel(kind == .voice ? "Record voice message" : "Record video message")
            .accessibilityHint("Hold to record, release to send. Slide left to cancel, up to lock.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                Task { _ = await recorder.begin(kind, locked: true) }
            }
            .accessibilityIdentifier(kind == .voice ? "chat.recordVoice" : "chat.recordVideo")
    }

    private var hold: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !pressing {
                    pressing = true
                    guard !recorder.isRecording else { return }
                    Task {
                        let started = await recorder.begin(kind)
                        if started { startTrigger += 1 }
                        // Let go before the camera/mic was ready: that was a tap.
                        if started, !pressing, recorder.phase == .holding {
                            recorder.cancel()
                            recorder.errorMessage = String(localized: "Hold to record, release to send.")
                        }
                    }
                    return
                }
                guard recorder.phase == .holding, recorder.kind == kind else { return }
                recorder.drag = value.translation
                if value.translation.height < -ChatMediaRecorder.lockDistance {
                    recorder.lock()
                } else if value.translation.width < -ChatMediaRecorder.cancelDistance {
                    recorder.cancel()
                }
            }
            .onEnded { _ in
                pressing = false
                guard recorder.phase == .holding, recorder.kind == kind else { return }
                Task {
                    if let recording = await recorder.finish() { onSend(recording) }
                }
            }
    }
}

/// Replaces the message field while recording: timer, the slide hints while
/// holding, and trash once locked.
struct ChatRecordingBar: View {
    let recorder: ChatMediaRecorder

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            HStack(spacing: 10) {
                Circle()
                    .fill(Palette.pink)
                    .frame(width: 10, height: 10)
                    .opacity(Int(recorder.elapsed * 2).isMultiple(of: 2) ? 1 : 0.35)
                Text(VoiceNoteBubble.format(recorder.elapsed))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Text("/ \(VoiceNoteBubble.format(recorder.kind.maxDuration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.textTertiary)
                Spacer(minLength: 4)
                if recorder.phase == .holding {
                    Label("Slide to cancel", systemImage: "chevron.left")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .offset(x: min(recorder.drag.width / 3, 0))
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.mint)
                        .overlay(alignment: .top) {
                            Image(systemName: "chevron.up")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(Palette.mint)
                                .offset(y: -12)
                        }
                        .accessibilityLabel("Slide up to lock")
                } else {
                    Button("Delete recording", systemImage: "trash.fill", role: .destructive) {
                        recorder.cancel()
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(Palette.pink)
                    .accessibilityIdentifier("chat.recordTrash")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Palette.surfaceRaised, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.recordingBar")
    }
}

/// The round selfie preview while recording a video note.
struct VideoNotePreview: View {
    let recorder: ChatMediaRecorder

    var body: some View {
        ZStack {
            if CameraController.isAvailable {
                CameraPreview(session: recorder.camera.session)
            } else {
                Palette.seededGradient("video-note")
                    .overlay {
                        Label("Selfie camera", systemImage: "camera.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
            }
        }
        .frame(width: 230, height: 230)
        .clipShape(.circle)
        .overlay {
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                Circle()
                    .trim(from: 0, to: min(recorder.elapsed / recorder.kind.maxDuration, 1))
                    .stroke(Palette.pink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 20)
        .accessibilityLabel("Recording a video message")
    }
}
