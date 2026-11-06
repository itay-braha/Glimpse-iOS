import Foundation

/// An example Glimpse shown during onboarding, so people see what a good one looks like
/// before filming their own. Always labelled "Example" on screen: these aren't members.
///
/// To use real footage, add `showcase-<prompt>.mp4` (vertical, muted-friendly, 5–10 s,
/// e.g. `showcase-quick_hello.mp4`) to `ios/Glimpse/Resources/Showcase/`. Until then an
/// animated stand-in plays.
struct ShowcaseClip: Identifiable, Hashable, Sendable {
    let prompt: VibePrompt
    let name: String
    let age: Int

    var id: String { prompt.rawValue }

    var videoURL: URL? {
        Bundle.main.url(forResource: "showcase-\(prompt.rawValue)", withExtension: "mp4")
    }

    static let examples: [ShowcaseClip] = [
        ShowcaseClip(prompt: .quickHello, name: "Noa", age: 26),
        ShowcaseClip(prompt: .inMyElement, name: "Maya", age: 28),
        ShowcaseClip(prompt: .bestFriend, name: "Shira", age: 25),
    ]

    static func example(for prompt: VibePrompt) -> ShowcaseClip {
        examples.first { $0.prompt == prompt } ?? ShowcaseClip(prompt: prompt, name: "Noa", age: 26)
    }
}
