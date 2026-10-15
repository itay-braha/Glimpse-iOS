import Observation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// "Quick upload": a clip from the camera roll. MP4/MOV only; anything longer
/// than 15 seconds is trimmed to its first 15; compressed on the phone to stay
/// under 20 MB; hosted privately with no handle or link attached.
struct UploadVideoView: View {
    let onAdded: (ProfileVideo) -> Void

    @Environment(AppModel.self) private var app
    @State private var model = UploadVideoModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var preferences = PlaybackPreferences.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch model.state {
                case .idle:
                    intro
                case .inspecting:
                    working("Checking your video…")
                case let .review(review):
                    reviewSection(review)
                case .uploading:
                    working("Compressing and uploading…")
                }
                if let error = model.errorMessage {
                    ErrorText(error)
                }
            }
            .padding(20)
        }
        .background(Palette.midnight)
        .navigationTitle("Quick upload")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                await model.load(item)
                pickerItem = nil
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Pick a clip from your camera roll")
                .font(.glimpseTitle2)
            VStack(alignment: .leading, spacing: 12) {
                RequirementRow(symbol: "film", text: "MP4 or MOV")
                RequirementRow(symbol: "timer", text: "Up to 15 seconds. Longer clips are trimmed to the first 15.")
                RequirementRow(symbol: "externaldrive", text: "Up to 20 MB. We compress it on your phone first.")
                RequirementRow(symbol: "rectangle.portrait", text: "Vertical (9:16) fills the screen best.")
            }
            PrivacyNote()
            PhotosPicker(selection: $pickerItem, matching: .videos, preferredItemEncoding: .current) {
                Label("Choose a video", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.glimpse)
            .accessibilityIdentifier("upload.choose")
            if app.isDemo {
                Button("Use a sample video") {
                    Task { await model.loadSample() }
                }
                .buttonStyle(.glimpseSecondary)
                .accessibilityIdentifier("upload.sample")
            }
        }
    }

    private func reviewSection(_ review: UploadVideoModel.Review) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            LoopingVideoPlayer(url: review.fileURL, isActive: true, isMuted: preferences.isMuted)
                .aspectRatio(9 / 16, contentMode: .fit)
                .frame(maxWidth: 250)
                .background(Color.black)
                .clipShape(.rect(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.stroke))
                .overlay(alignment: .bottomTrailing) { MuteToggle(size: 38).padding(10) }
                .overlay(alignment: .top) {
                    if let prompt = model.prompt {
                        PromptSticker(prompt: prompt).padding(.top, 12)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("upload.preview")

            VStack(alignment: .leading, spacing: 10) {
                CheckRow(state: .ok, text: "MP4 or MOV")
                let seconds = Int(review.inspection.durationSeconds.rounded())
                if review.inspection.willTrim {
                    CheckRow(state: .note, text: "It's \(seconds)s, so we'll use the first 15 seconds.")
                } else {
                    CheckRow(state: .ok, text: "\(max(seconds, 1))s, within 15 seconds")
                }
                if review.inspection.isVertical {
                    CheckRow(state: .ok, text: "Vertical, fills the screen")
                } else {
                    CheckRow(state: .note, text: "Not vertical. 9:16 looks best; this one gets cropped to fill the screen.")
                }
                CheckRow(state: .ok, text: "Compressed to stay under 20 MB")
            }
            .accessibilityIdentifier("upload.checks")

            VStack(alignment: .leading, spacing: 8) {
                Text("Add a prompt? It gives people something to answer.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        SelectableChip(title: "No prompt", isSelected: model.prompt == nil) { model.prompt = nil }
                        ForEach(VibePrompt.allCases) { prompt in
                            SelectableChip(title: prompt.text, isSelected: model.prompt == prompt) { model.prompt = prompt }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            PrivacyNote()

            HStack(spacing: 12) {
                PhotosPicker(selection: $pickerItem, matching: .videos, preferredItemEncoding: .current) {
                    Text("Choose another")
                }
                .buttonStyle(.glimpseSecondary)
                Button("Add to my profile") {
                    Task {
                        if let video = await model.upload(using: app.backend) {
                            onAdded(video)
                        }
                    }
                }
                .buttonStyle(.glimpse)
                .accessibilityIdentifier("upload.add")
            }
        }
    }

    private func working(_ text: String) -> some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large)
            Text(text).foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }
}

@MainActor
@Observable
final class UploadVideoModel {
    struct Review: Equatable {
        let fileURL: URL
        let inspection: VideoCompressor.Inspection
    }

    enum State: Equatable {
        case idle
        case inspecting
        case review(Review)
        case uploading
    }

    nonisolated static let acceptedTypes: [UTType] = [.mpeg4Movie, .quickTimeMovie]

    private(set) var state: State = .idle
    var errorMessage: String?
    var prompt: VibePrompt?

    nonisolated static func isAccepted(_ types: [UTType]) -> Bool {
        types.contains { type in acceptedTypes.contains { type.conforms(to: $0) } }
    }

    func load(_ item: PhotosPickerItem) async {
        errorMessage = nil
        guard Self.isAccepted(item.supportedContentTypes) else {
            errorMessage = "Pick an MP4 or MOV video."
            return
        }
        let previous = state
        state = .inspecting
        do {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                throw GlimpseError.message("Couldn't open that video.")
            }
            try await inspect(movie.url)
        } catch {
            errorMessage = GlimpseError.describe(error)
            state = previous == .inspecting ? .idle : previous
        }
    }

    /// Demo builds (and the simulator, whose library has no videos) try the flow with a sample clip.
    func loadSample() async {
        errorMessage = nil
        state = .inspecting
        do {
            guard let remote = URL(string: DemoData.clipURLs[1]) else { return }
            let (downloaded, _) = try await URLSession.shared.download(from: remote)
            let local = FileManager.default.temporaryDirectory.appending(path: "sample-\(UUID().uuidString).mp4")
            try FileManager.default.moveItem(at: downloaded, to: local)
            try await inspect(local)
        } catch {
            errorMessage = GlimpseError.describe(error)
            state = .idle
        }
    }

    func upload(using backend: any GlimpseBackend) async -> ProfileVideo? {
        guard case let .review(review) = state else { return nil }
        errorMessage = nil
        state = .uploading
        do {
            var clip = try await VideoCompressor.prepare(review.fileURL, source: .upload)
            clip.promptKey = prompt?.rawValue
            return try await backend.uploadClip(clip)
        } catch {
            errorMessage = GlimpseError.describe(error)
            state = .review(review)
            return nil
        }
    }

    private func inspect(_ url: URL) async throws {
        let inspection = try await VideoCompressor.inspect(url)
        state = .review(Review(fileURL: url, inspection: inspection))
    }
}

/// A picked video, copied out of the picker's temporary sandbox.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension.lowercased()
            let copy = FileManager.default.temporaryDirectory.appending(path: "pick-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

private struct RequirementRow: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text).foregroundStyle(Palette.textPrimary)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Palette.mint)
        }
        .font(.subheadline)
    }
}

private struct CheckRow: View {
    enum Kind {
        case ok
        case note
    }

    let state: Kind
    let text: String

    var body: some View {
        Label {
            Text(text).foregroundStyle(Palette.textPrimary)
        } icon: {
            Image(systemName: state == .ok ? "checkmark.circle.fill" : "info.circle.fill")
                .foregroundStyle(state == .ok ? Palette.mint : Palette.amber)
        }
        .font(.subheadline)
    }
}

private struct PrivacyNote: View {
    var body: some View {
        Label("Hosted privately by Glimpse. Only people you're shown to can play it, and no username, handle or link is attached.", systemImage: "lock.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Palette.textSecondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: .rect(cornerRadius: 14))
    }
}
