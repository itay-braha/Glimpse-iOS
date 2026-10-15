import SwiftUI

struct RecorderView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var model: RecorderModel

    let onSaved: (ProfileVideo?) -> Void

    init(purpose: RecordingPurpose = .profileClip, onSaved: @escaping (ProfileVideo?) -> Void) {
        _model = State(initialValue: RecorderModel(purpose: purpose))
        self.onSaved = onSaved
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch model.state {
            case .preparing:
                ProgressView()
            case let .unavailable(message):
                unavailable(message)
            case .ready, .recording:
                CameraPreview(session: model.camera.session)
                    .ignoresSafeArea()
                captureControls
            case let .review(url):
                LoopingVideoPlayer(url: url, isActive: true, isMuted: false)
                    .ignoresSafeArea()
                reviewControls
            case .uploading:
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large)
                    Text("Compressing and uploading…").foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .overlay(alignment: .topLeading) {
            Button("Close", systemImage: "xmark") {
                dismiss()
            }
            .labelStyle(.iconOnly)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: .circle)
            .padding()
        }
        .task { await model.prepare() }
        .onDisappear { model.teardown() }
        .alert("Couldn't save", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var captureControls: some View {
        VStack {
            Spacer()
            Text(model.purpose.prompt)
                .multilineTextAlignment(.center)
                .font(.glimpseHeadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: .capsule)
                .opacity(isRecording ? 0 : 1)

            HStack {
                Spacer().frame(width: 56)
                Spacer()
                RecordButton(startedAt: recordingStart, maxDuration: model.purpose.maxDuration) {
                    model.toggleRecording()
                }
                Spacer()
                Button("Flip camera", systemImage: "arrow.triangle.2.circlepath.camera") {
                    model.flip()
                }
                .disabled(model.purpose.usesFrontCameraOnly)
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: .circle)
                .opacity(isRecording || model.purpose.usesFrontCameraOnly ? 0 : 1)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
    }

    private var reviewControls: some View {
        VStack(spacing: 14) {
            if let prompt = model.selectedPrompt {
                PromptSticker(prompt: prompt)
                    .padding(.top, 70)
            }
            Spacer()
            if model.purpose == .profileClip {
                PromptPicker(selection: $model.selectedPrompt)
            }
            HStack(spacing: 12) {
                Button("Retake") { model.retake() }
                    .buttonStyle(.glimpseSecondary)
                Button(model.purpose == .profileClip ? "Use this clip" : "Submit for review") {
                    Task {
                        let result = await model.upload(using: app.backend)
                        if result.succeeded {
                            onSaved(result.video)
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.glimpse)
            }
            .padding(24)
        }
    }

    private func unavailable(_ message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 44))
                .foregroundStyle(Palette.textTertiary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.textSecondary)
            if app.isDemo {
                Button("Use a sample moment") {
                    Task {
                        let result = await model.useSampleClip(using: app.backend)
                        if result.succeeded {
                            onSaved(result.video)
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.glimpse)
                .padding(.top, 8)
            }
        }
        .padding(32)
    }

    private var isRecording: Bool {
        if case .recording = model.state { return true }
        return false
    }

    private var recordingStart: Date? {
        if case let .recording(startedAt) = model.state { return startedAt }
        return nil
    }
}

/// Guided prompts: suggested, never forced (skip is the default).
private struct PromptPicker: View {
    @Binding var selection: VibePrompt?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add a prompt? It gives people something to answer.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 24)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    SelectableChip(title: "No prompt", isSelected: selection == nil) { selection = nil }
                    ForEach(VibePrompt.allCases) { prompt in
                        SelectableChip(title: prompt.text, isSelected: selection == prompt) { selection = prompt }
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// Shutter button with a ring that fills over the recording limit.
private struct RecordButton: View {
    let startedAt: Date?
    let maxDuration: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TimelineView(.animation(paused: startedAt == nil)) { context in
                let progress = startedAt.map {
                    min(context.date.timeIntervalSince($0) / maxDuration, 1)
                } ?? 0
                ZStack {
                    Circle().stroke(.white.opacity(0.35), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Palette.pink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    RoundedRectangle(cornerRadius: startedAt == nil ? 32 : 8)
                        .fill(Palette.pink)
                        .frame(width: startedAt == nil ? 62 : 30, height: startedAt == nil ? 62 : 30)
                        .animation(.snappy, value: startedAt == nil)
                }
                .frame(width: 84, height: 84)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(startedAt == nil ? "Start recording" : "Stop recording")
    }
}
