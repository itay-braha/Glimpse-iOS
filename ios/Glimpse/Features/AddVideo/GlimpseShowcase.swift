import SwiftUI

/// Full-bleed example Glimpses that play one after another, Stories-style, behind the
/// "Let others get a Glimpse of YOU" screen. Shows people what they're about to make.
struct GlimpseShowcase: View {
    var clips: [ShowcaseClip] = ShowcaseClip.examples
    /// False while something covers the screen, so nothing plays unseen.
    var isActive = true
    var secondsPerClip: Double = 5

    @State private var index = 0
    @State private var progress: Double = 0

    private var clip: ShowcaseClip { clips[index % max(clips.count, 1)] }

    var body: some View {
        ZStack(alignment: .top) {
            ShowcaseStage(clip: clip, isActive: isActive)
                .id(clip.id)
                .transition(.opacity)
                .ignoresSafeArea()

            GradientScrim(edge: .top, height: 230, strength: 0.6)
                .ignoresSafeArea(edges: .top)

            VStack(alignment: .leading, spacing: 14) {
                ProgressSegments(count: clips.count, current: index, progress: progress)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: "\(clip.name), \(clip.age)")
                            .font(.glimpseTitle2)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 6)
                        PromptSticker(prompt: clip.prompt)
                    }
                    .id(clip.id)
                    .transition(.opacity.combined(with: .offset(y: 6)))
                    Spacer(minLength: 12)
                    ExampleTag()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
        .contentShape(.rect)
        .onTapGesture { advance() }
        .task(id: TaskKey(index: index, isActive: isActive)) { await play() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Example Glimpse: \(clip.name), \(clip.age). \(clip.prompt.text)"))
    }

    private struct TaskKey: Equatable {
        let index: Int
        let isActive: Bool
    }

    private func play() async {
        progress = 0
        guard isActive, clips.count > 1 else { return }
        try? await Task.sleep(for: .milliseconds(40))
        withAnimation(.linear(duration: secondsPerClip)) { progress = 1 }
        try? await Task.sleep(for: .seconds(secondsPerClip))
        guard !Task.isCancelled else { return }
        advance()
    }

    private func advance() {
        guard clips.count > 1 else { return }
        withAnimation(.easeInOut(duration: 0.55)) {
            index = (index + 1) % clips.count
        }
    }
}

/// One example clip: the real video when it's bundled, otherwise the animated stand-in.
struct ShowcaseStage: View {
    let clip: ShowcaseClip
    var isActive = true
    /// How far above centre the stand-in's subject sits, as a share of the height,
    /// so it stays clear of text laid over the lower part.
    var subjectLift: Double = 0.12

    var body: some View {
        if let url = clip.videoURL {
            LoopingVideoPlayer(url: url, isActive: isActive, isMuted: true, protected: false)
        } else {
            ShowcaseStandIn(prompt: clip.prompt, isActive: isActive, subjectLift: subjectLift)
        }
    }
}

/// "Example" marker, so nobody mistakes a showcase clip for a member.
struct ExampleTag: View {
    var body: some View {
        Text("Example")
            .font(.glimpseCaption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.45), in: .capsule)
            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
    }
}

/// Stories-style bars: done, playing (filling), and up next.
private struct ProgressSegments: View {
    let count: Int
    let current: Int
    let progress: Double

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(0.28))
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(.white)
                                .frame(width: proxy.size.width * fill(index))
                        }
                    }
                    .clipShape(.capsule)
                    .frame(height: 3)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }

    private func fill(_ index: Int) -> Double {
        if index < current { return 1 }
        return index == current ? progress : 0
    }
}

/// Stands in for footage until real example clips are bundled: a slowly drifting,
/// softly lit scene around the prompt's emoji, with the feel of a handheld camera.
private struct ShowcaseStandIn: View {
    let prompt: VibePrompt
    let isActive: Bool
    let subjectLift: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !isActive)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Palette.seededGradient(prompt.rawValue)
                    glow(Palette.pink, diameter: size.width * 0.95)
                        .offset(x: size.width * 0.3 + sin(t / 3.1) * 28, y: -size.height * 0.22 + cos(t / 3.7) * 34)
                    glow(Palette.mint, diameter: size.width * 0.8)
                        .offset(x: -size.width * 0.32 + cos(t / 4.3) * 30, y: size.height * 0.18 + sin(t / 2.9) * 30)
                    glow(Palette.violet, diameter: size.width * 0.7)
                        .offset(x: sin(t / 5.2) * 40, y: size.height * 0.4)

                    Text(prompt.emoji)
                        .font(.system(size: min(size.width, size.height) * 0.3))
                        .shadow(color: .black.opacity(0.3), radius: 24, y: 12)
                        .rotationEffect(.degrees(sin(t / 1.6) * 5))
                        .scaleEffect(1 + sin(t / 1.3) * 0.035)
                        .offset(x: sin(t / 2.3) * 8, y: -size.height * subjectLift + cos(t / 1.9) * 10)

                    RadialGradient(
                        colors: [.clear, .black.opacity(0.45)],
                        center: .center,
                        startRadius: min(size.width, size.height) * 0.25,
                        endRadius: max(size.width, size.height) * 0.75
                    )
                }
                // A gentle sway, like a phone held at arm's length.
                .scaleEffect(1.08)
                .offset(x: sin(t / 2.7) * 4, y: cos(t / 3.3) * 5)
                .frame(width: size.width, height: size.height)
                .clipped()
            }
        }
        .accessibilityHidden(true)
    }

    private func glow(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(color.opacity(0.38))
            .frame(width: diameter, height: diameter)
            .blur(radius: diameter * 0.3)
    }
}
