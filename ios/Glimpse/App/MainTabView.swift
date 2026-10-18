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
        .sheet(isPresented: $app.askForAlerts) {
            AlertChoiceSheet { scope in
                Task { await app.choseAlerts(scope) }
            }
        }
        .sheet(isPresented: $app.needsTermsAcceptance) {
            TermsUpdateSheet {
                Task { await app.acceptUpdatedTerms() }
            }
        }
        .sheet(item: $app.alertNudge) { nudge in
            AlertNudgeSheet(nudge: nudge) { accepted, never in
                Task { await app.answerNudge(nudge, accepted: accepted, never: never) }
            }
        }
        .sheet(item: $app.paywall) { reason in
            PaywallView(reason: reason)
        }
        .task { await app.didBecomeReady() }
    }
}
