import SwiftUI

/// Connections the 20-cap released in the last 30 days. Nobody can message
/// from here; Glimpse+ members can ask for a consent-based second chance.
struct MissedConnectionsView: View {
    @Environment(AppModel.self) private var app
    @State private var missed: [MissedConnection] = []
    @State private var hasLoaded = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(missed) { connection in
                    HStack(spacing: 14) {
                        AvatarView(name: connection.displayName, size: 48)
                            .grayscale(0.6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(connection.displayName), \(connection.age)")
                                .font(.glimpseHeadline)
                            Text("Released \(connection.endedAt, format: .relative(presentation: .named))")
                                .font(.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer()
                        statusButton(for: connection)
                    }
                    .padding(.vertical, 4)
                }
                if missed.isEmpty && hasLoaded {
                    Text("No missed connections. When your circle is full, released connections show up here for 30 days.")
                        .foregroundStyle(Palette.textSecondary)
                }
            } footer: {
                Text("A second chance asks them to reconnect. It only becomes a match if they accept.")
            }

            if let errorMessage {
                Section { ErrorText(errorMessage) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.midnight)
        .listRowBackground(Palette.surface)
        .navigationTitle("Missed connections")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func statusButton(for connection: MissedConnection) -> some View {
        switch connection.secondChanceStatus {
        case "pending":
            Text("Sent").font(.caption.weight(.semibold)).foregroundStyle(Palette.textSecondary)
        case "accepted":
            Text("Reconnected").font(.caption.weight(.semibold)).foregroundStyle(Palette.mint)
        case "declined":
            Text("Passed").font(.caption.weight(.semibold)).foregroundStyle(Palette.textTertiary)
        default:
            Button("Second chance") {
                Task { await requestSecondChance(connection) }
            }
            .font(.caption.weight(.bold))
            .buttonStyle(.borderedProminent)
            .tint(Palette.violet)
        }
    }

    private func load() async {
        do {
            missed = try await app.backend.missedConnections()
            errorMessage = nil
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
        hasLoaded = true
    }

    private func requestSecondChance(_ connection: MissedConnection) async {
        do {
            try await app.backend.requestSecondChance(matchID: connection.matchID)
            app.track("second_chance_requested")
            await load()
        } catch GlimpseError.plusRequired {
            app.paywall = .secondChance
        } catch {
            errorMessage = GlimpseError.describe(error)
        }
    }
}
