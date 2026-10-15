import SwiftUI

/// Glimpse profiles are video-only, so onboarding ends with the first moment:
/// the "Let others get a Glimpse of YOU" hub.
struct FirstVideoView: View {
    @Environment(AppModel.self) private var app
    @State private var route: AddVideoRoute?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    GlimpseOfYouHeader()
                    VideoHubOptions { route = $0 }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button("Sign out") {
                Task { await app.signOut() }
            }
            .font(.subheadline)
            .foregroundStyle(Palette.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .background(Palette.midnight.ignoresSafeArea())
        .sheet(item: $route) { route in
            NavigationStack {
                AddVideoDestination(route: route) { _ in
                    self.route = nil
                    Task { await app.refreshProfile() }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { self.route = nil }
                    }
                }
            }
        }
    }
}

struct VideoSourceCard: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.14), in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.glimpseHeadline).foregroundStyle(Palette.textPrimary)
                    Text(detail).font(.subheadline).foregroundStyle(Palette.textSecondary)
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
