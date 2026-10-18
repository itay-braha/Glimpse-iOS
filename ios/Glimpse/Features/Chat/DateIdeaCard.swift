import SwiftUI

/// "A first date idea for you two": shown to both people after a good Vibe Check
/// or a long video call. A partner spot near the middle of them, or a general idea.
struct DateIdeaCard: View {
    let idea: DateIdea
    let onDirections: (URL) -> Void
    let onSendToChat: (String) -> Void
    let onAnother: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("A first date idea for you two", systemImage: "mappin.and.ellipse")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Palette.amber)
                Spacer()
                Button("Dismiss", systemImage: "xmark", action: onDismiss)
                    .labelStyle(.iconOnly)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.textTertiary)
                    .accessibilityIdentifier("dateIdea.dismiss")
            }

            if let spot = idea.spot {
                HStack(spacing: 12) {
                    Image(systemName: spot.category.symbol)
                        .font(.title3)
                        .foregroundStyle(Palette.amber)
                        .frame(width: 40, height: 40)
                        .background(Palette.amber.opacity(0.15), in: .circle)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spot.name).font(.glimpseHeadline)
                        Text(details(spot))
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                if let tagline = spot.tagline {
                    Text(tagline)
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
            } else if let text = idea.idea {
                Text(text).font(.glimpseHeadline)
            }

            HStack(spacing: 8) {
                if let link = idea.spot?.mapsLink {
                    Button("Directions", systemImage: "map.fill") { onDirections(link) }
                        .buttonStyle(GlimpseButtonStyle(kind: .primary))
                        .accessibilityIdentifier("dateIdea.directions")
                }
                Button("Suggest it", systemImage: "paperplane.fill") { onSendToChat(message) }
                    .buttonStyle(GlimpseButtonStyle(kind: .secondary))
                    .accessibilityIdentifier("dateIdea.send")
                Button("Another idea", systemImage: "shuffle", action: onAnother)
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Palette.surfaceRaised, in: .circle)
                    .accessibilityIdentifier("dateIdea.another")
            }
        }
        .padding(14)
        .background(Palette.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.amber.opacity(0.45)))
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dateIdea")
    }

    private func details(_ spot: DateSpot) -> String {
        var parts = [spot.category.title]
        if let price = spot.priceText { parts.append(price) }
        if let km = spot.distanceKm { parts.append(String(format: "%.1f km", km)) }
        if let city = spot.city { parts.append(city) }
        return parts.joined(separator: " · ")
    }

    /// A ready-to-send message for the chat (they can edit it first).
    private var message: String {
        if let spot = idea.spot {
            return "How about \(spot.name)\(spot.address.map { " (\($0))" } ?? "")? 😊"
        }
        return "Idea for us: \((idea.idea ?? "").lowercased()) 😊"
    }
}
