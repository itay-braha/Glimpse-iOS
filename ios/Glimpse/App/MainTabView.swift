import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app

        TabView(selection: $app.selectedTab) {
            Tab("Discover", systemImage: "play.rectangle.on.rectangle.fill", value: AppTab.discover) {
                FeedView()
            }
            Tab("Connections", systemImage: "bubble.left.and.bubble.right.fill", value: AppTab.connections) {
                MatchesView()
            }
            Tab("Profile", systemImage: "person.crop.circle.fill", value: AppTab.profile) {
                MyProfileView()
            }
        }
        .tint(Palette.mint)
        .sheet(item: $app.paywall) { reason in
            PaywallView(reason: reason)
        }
        .task { await app.didBecomeReady() }
    }
}
