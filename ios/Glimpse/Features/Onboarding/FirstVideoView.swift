import SwiftUI

/// Glimpse profiles are video-only, so onboarding ends with the first moment:
/// the "Let others get a Glimpse of YOU" hub. Example Glimpses play full-screen
/// behind it, and the choices sit on a panel that fades up over the video.
struct FirstVideoView: View {
    @Environment(AppModel.self) private var app
    @State private var route: AddVideoRoute?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Palette.midnight.ignoresSafeArea()

                GlimpseShowcase(isActive: route == nil)
                    .frame(height: proxy.size.height * 0.7)
                    .frame(maxHeight: .infinity, alignment: .top)

                ScrollView {
                    VStack(spacing: 0) {
                        // Leaves the top of the screen to the example clip.
                        Spacer(minLength: proxy.size.height * 0.4)
                        panel
                    }
                    .frame(minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
        }
        .sheet(item: $route) { route in
            NavigationStack {
                AddVideoDestination(route: route) { _ in
                    self.route = nil
                    Task { await app.refreshProfile() }
                } onSwitch: { next in
                    self.route = next
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { self.route = nil }
                    }
                }
            }
        }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 24) {
            GlimpseOfYouHeader()
            // The first moment is always one Glimpse hosts, so a profile can't
            // go empty if a linked post later disappears.
            VideoHubOptions(canLink: false) { route = $0 }

            Button("Sign out") {
                Task { await app.signOut() }
            }
            .font(.subheadline)
            .foregroundStyle(Palette.textTertiary)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 72)
        .padding(.bottom, 12)
        .background {
            LinearGradient(
                stops: [
                    .init(color: Palette.midnight.opacity(0), location: 0),
                    .init(color: Palette.midnight.opacity(0.88), location: 0.1),
                    .init(color: Palette.midnight, location: 0.2),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct VideoSourceCard<Icon: View>: View {
    let title: String
    let detail: String
    let action: () -> Void
    let icon: Icon

    @Environment(\.isEnabled) private var isEnabled

    init(title: String, detail: String, action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.detail = detail
        self.action = action
        self.icon = icon()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                icon
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(title)).font(.glimpseHeadline).foregroundStyle(Palette.textPrimary)
                    Text(LocalizedStringKey(detail)).font(.subheadline).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .background(Palette.surface, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.stroke))
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
    }
}

extension VideoSourceCard where Icon == SourceSymbol {
    init(symbol: String, tint: Color, title: String, detail: String, action: @escaping () -> Void) {
        self.init(title: title, detail: detail, action: action) {
            SourceSymbol(symbol: symbol, tint: tint)
        }
    }
}

struct SourceSymbol: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.title2)
            .foregroundStyle(tint)
            .frame(width: 48, height: 48)
            .background(tint.opacity(0.14), in: .rect(cornerRadius: 14))
    }
}
