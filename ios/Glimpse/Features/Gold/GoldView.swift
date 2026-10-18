import SwiftUI

/// Glimpse Gold: Spotlight, Rewind, Travel mode and clip insights in one place.
struct GoldView: View {
    @Environment(AppModel.self) private var app
    @State private var model = GoldModel()
    @State private var city = ""
    @State private var days = 7
    @State private var showPaywall = false

    var body: some View {
        List {
            if model.status.isGold {
                Section {
                    Label("You're a Glimpse Gold member", systemImage: "crown.fill")
                        .foregroundStyle(Palette.amber)
                }
                spotlight
                rewind
                travel
                insights
            } else if model.hasLoaded {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Glimpse Gold", systemImage: "crown.fill")
                            .font(.glimpseHeadline)
                            .foregroundStyle(Palette.amber)
                        Text("Weekly Spotlight, clip insights, Travel mode and Rewind, on top of everything in Glimpse+.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                        Button("See Glimpse Gold") { showPaywall = true }
                            .buttonStyle(.glimpse)
                            .accessibilityIdentifier("gold.upsell")
                    }
                    .padding(.vertical, 6)
                }
            }

            if let error = model.errorMessage {
                Section { ErrorText(error) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.midnight)
        .navigationTitle("Glimpse Gold")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load(using: app.backend) }
        .sheet(isPresented: $showPaywall, onDismiss: {
            Task { await model.load(using: app.backend) }
        }) {
            PaywallView(reason: .gold)
        }
        .disabled(model.isWorking)
    }

    // MARK: Sections

    private var spotlight: some View {
        Section {
            if let until = model.status.spotlightUntil, model.status.isSpotlightLive {
                Label("You're in the Spotlight until \(until.formatted(date: .omitted, time: .shortened))", systemImage: "sun.max.fill")
                    .foregroundStyle(Palette.amber)
                    .accessibilityIdentifier("gold.spotlightLive")
            } else if model.status.canStartSpotlight {
                Button("Start my Spotlight", systemImage: "sun.max.fill") {
                    Task { await model.startSpotlight(using: app.backend) }
                }
                .accessibilityIdentifier("gold.startSpotlight")
            } else if let next = model.status.spotlightAvailableAt {
                Label("Next Spotlight \(next.formatted(.relative(presentation: .named)))", systemImage: "sun.min")
                    .foregroundStyle(Palette.textSecondary)
            }
        } header: {
            Text("Weekly Spotlight")
        } footer: {
            Text("For 30 minutes you're shown near the front to people who'd likely like you, only inside their own filters. Once a week. Best on a busy evening.")
        }
    }

    private var rewind: some View {
        Section {
            Label("\(model.status.rewindsLeft) of 5 rewinds left today", systemImage: "arrow.uturn.backward")
        } header: {
            Text("Rewind")
        } footer: {
            Text("Passed someone too fast? Tap ↺ at the top of Discover to bring them back. They never know.")
        }
    }

    private var travel: some View {
        Section {
            if model.status.isTravelling, let place = model.status.travelCity, let until = model.status.travelUntil {
                Label("Visiting \(place) until \(until.formatted(date: .abbreviated, time: .omitted))", systemImage: "airplane")
                    .foregroundStyle(Palette.mint)
                    .accessibilityIdentifier("gold.travelling")
                Button("End trip and go home", systemImage: "house.fill", role: .destructive) {
                    Task { await model.endTrip(using: app.backend) }
                }
            } else {
                TextField("City you're visiting", text: $city)
                    .textContentType(.addressCity)
                    .accessibilityIdentifier("gold.city")
                Stepper("For \(days) day\(days == 1 ? "" : "s")", value: $days, in: 1...14)
                Button("Start trip", systemImage: "airplane.departure") {
                    Task { await model.startTrip(to: city, days: days, using: app.backend) }
                }
                .disabled(city.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("gold.startTrip")
            }
        } header: {
            Text("Travel mode")
        } footer: {
            Text("Show up in an open city a few days before you arrive, and see people there. Your trip ends on its own and you're back home.")
        }
    }

    private var insights: some View {
        Section {
            if model.videos.isEmpty {
                Text("Add a clip to see how it does.")
                    .foregroundStyle(Palette.textSecondary)
            }
            ForEach(Array(model.videos.enumerated()), id: \.element.id) { index, video in
                InsightRow(index: index, video: video, insight: model.insight(for: video))
            }
        } header: {
            Text("Clip insights · last 30 days")
        } footer: {
            Text("Totals only, never who. Numbers appear once 5 different people have seen a clip.")
        }
    }
}

private struct InsightRow: View {
    let index: Int
    let video: ProfileVideo
    let insight: ClipInsight?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Clip \(index + 1)").font(.glimpseHeadline)
                Text(video.isEmbed ? "Linked post" : "Hosted clip")
                    .font(.caption)
                    .foregroundStyle(Palette.textTertiary)
                Spacer()
                Text("\(insight?.viewers ?? 0) people")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
            }
            if let insight, insight.enoughData {
                HStack(spacing: 14) {
                    Metric(value: percent(insight.watchedThrough), label: "watched through", tint: Palette.mint)
                    Metric(value: percent(insight.skipped), label: "skipped", tint: Palette.pink)
                    Metric(value: "\(insight.likes ?? 0)", label: "likes", tint: Palette.amber)
                    Metric(value: "\(insight.moreTaps ?? 0)", label: "+more", tint: Palette.violet)
                }
            } else {
                Text("Not enough views yet")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gold.insight")
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "–" }
        return "\(Int((value * 100).rounded()))%"
    }
}

private struct Metric: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.glimpseHeadline).foregroundStyle(tint)
            Text(LocalizedStringKey(label)).font(.caption2).foregroundStyle(Palette.textTertiary)
        }
    }
}
