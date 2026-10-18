import SwiftUI

/// Shows a video normally, or, when the viewer has Sensitive Content Warning on and the
/// video may contain nudity, blurs it behind a warning with "Show anyway" (Apple's
/// intervention pattern). Does nothing on phones where the feature is off.
struct SensitiveVideoGate<Content: View>: View {
    let url: URL?
    @ViewBuilder let content: Content

    @State private var isSensitive = false
    @State private var revealed = false
    private let checker = SensitiveContentChecker.shared

    var body: some View {
        content
            .blur(radius: isSensitive && !revealed ? 40 : 0)
            .overlay {
                if isSensitive && !revealed {
                    warning
                }
            }
            .task(id: url) {
                revealed = false
                guard let url, checker.isAvailable else {
                    isSensitive = false
                    return
                }
                isSensitive = (try? await checker.isSensitive(url)) ?? false
            }
    }

    private var warning: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 34))
                .accessibilityHidden(true)
            Text("This video may be sensitive")
                .font(.glimpseHeadline)
            Text(checker.wantsDescriptiveInterventions
                 ? String(localized: "It may show nudity. You don't have to watch it, and you can report it if it shouldn't be here.")
                 : String(localized: "It may show nudity."))
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button("Show anyway") { revealed = true }
                .buttonStyle(GlimpseButtonStyle(kind: .secondary))
                .accessibilityIdentifier("sensitive.show")
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.35))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sensitive.warning")
    }
}
