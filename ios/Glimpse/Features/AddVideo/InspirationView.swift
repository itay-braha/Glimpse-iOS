import SwiftUI

/// "Get a Glimpse idea": a swipeable carousel of prompts, each opening the camera
/// with that prompt already on the clip.
struct InspirationView: View {
    let onAdded: (ProfileVideo) -> Void

    @State private var current: VibePrompt? = VibePrompt.inspiration.first
    @State private var recording: VibePrompt?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Need a spark?")
                    .font(.glimpseTitle2)
                Text("Pick a prompt, hit record, keep it under 15 seconds. Real beats polished.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(VibePrompt.inspiration) { prompt in
                        InspirationCard(prompt: prompt) { recording = prompt }
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.92)
                                    .opacity(phase.isIdentity ? 1 : 0.55)
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 28, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $current)
            .scrollIndicators(.hidden)

            HStack(spacing: 8) {
                ForEach(VibePrompt.inspiration) { prompt in
                    Capsule()
                        .fill(prompt == current ? Palette.mint : Palette.textTertiary)
                        .frame(width: prompt == current ? 22 : 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.snappy, value: current)
            .accessibilityHidden(true)

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .background(Palette.midnight)
        .navigationTitle("Glimpse ideas")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $recording) { prompt in
            RecorderView(prompt: prompt) { video in
                if let video { onAdded(video) }
            }
        }
    }
}

private struct InspirationCard: View {
    let prompt: VibePrompt
    let onRecord: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prompt.emoji)
                .font(.system(size: 68))
                .accessibilityHidden(true)
            Spacer(minLength: 24)
            Text(prompt.text)
                .font(.glimpseTitle)
                .foregroundStyle(.white)
            Text(prompt.idea)
                .font(.glimpseBody)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onRecord) {
                Label("Open camera", systemImage: "camera.fill")
            }
            .buttonStyle(.glimpse)
            .padding(.top, 8)
            .accessibilityIdentifier("inspiration.camera.\(prompt.rawValue)")
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 430, alignment: .leading)
        .background {
            ZStack {
                Palette.seededGradient(prompt.rawValue)
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            }
            .clipShape(.rect(cornerRadius: 28))
        }
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(.white.opacity(0.12)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(prompt.text). \(prompt.idea)")
    }
}
