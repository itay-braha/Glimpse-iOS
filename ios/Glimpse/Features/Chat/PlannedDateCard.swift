import SwiftUI

/// The date the two of them are planning, at the top of the chat: suggested (accept or
/// pick another time), set (directions, change the time, cancel), and afterwards the
/// private "How did it go?".
struct PlannedDateCard: View {
    let plan: PlannedDate
    let name: String
    let myID: UUID?
    let onAccept: () -> Void
    let onOtherTime: () -> Void
    let onCancel: () -> Void
    let onChangeTime: () -> Void
    let onDirections: (URL) -> Void
    let onCheckIn: (DateOutcome) -> Void

    private var proposedByMe: Bool { plan.proposedBy == myID }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if plan.canCheckIn {
                checkIn
            } else {
                header
                details
                actions
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(tint.opacity(0.5)))
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plannedDate")
    }

    private var tint: Color { plan.status == .confirmed ? Palette.mint : Palette.amber }

    private var header: some View {
        Label {
            Text(plan.status == .confirmed
                 ? String(localized: "Your date with \(name)")
                 : proposedByMe ? String(localized: "You suggested a date") : String(localized: "\(name) suggested a date"))
        } icon: {
            Image(systemName: plan.status == .confirmed ? "calendar.badge.checkmark" : "calendar.badge.clock")
        }
        .font(.caption.weight(.heavy))
        .foregroundStyle(tint)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(plan.place).font(.glimpseHeadline)
            HStack(spacing: 6) {
                Text(plan.startsAt.formatted(.dateTime.weekday(.wide).day().month().hour().minute()))
                if plan.status == .confirmed, plan.startsAt > .now {
                    Text("·")
                    Text(plan.startsAt, format: .relative(presentation: .named))
                }
            }
            .font(.subheadline)
            .foregroundStyle(Palette.textSecondary)
            if plan.status == .proposed && proposedByMe {
                Text("Waiting for \(name) to say yes")
                    .font(.caption)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        HStack(spacing: 8) {
            if plan.status == .proposed && !proposedByMe {
                Button("I'm in", action: onAccept)
                    .buttonStyle(GlimpseButtonStyle(kind: .primary))
                    .accessibilityIdentifier("plannedDate.accept")
                Button("Another time", action: onOtherTime)
                    .buttonStyle(GlimpseButtonStyle(kind: .secondary))
            } else {
                if let link = plan.mapsLink {
                    Button("Directions", systemImage: "map.fill") { onDirections(link) }
                        .buttonStyle(GlimpseButtonStyle(kind: .secondary))
                }
                if plan.status == .confirmed || proposedByMe {
                    Button("Change time", systemImage: "calendar.badge.clock", action: onChangeTime)
                        .buttonStyle(GlimpseButtonStyle(kind: .secondary))
                        .accessibilityIdentifier("plannedDate.changeTime")
                }
                Button(plan.status == .confirmed ? String(localized: "Cancel date") : String(localized: "Withdraw"), role: .destructive, action: onCancel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .accessibilityIdentifier("plannedDate.cancel")
            }
        }
    }

    private var checkIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How did it go with \(name)?").font(.glimpseHeadline)
            Text("Only Glimpse sees your answer, and \(name) is never told. Plans change, and that's fine.")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
            ForEach(DateOutcome.choices, id: \.self) { outcome in
                Button(outcome.label, systemImage: outcome.symbol) { onCheckIn(outcome) }
                    .buttonStyle(GlimpseButtonStyle(kind: outcome == .great ? .primary : .secondary))
                    .accessibilityIdentifier("checkIn.\(outcome.rawValue)")
            }
            Button(DateOutcome.skipped.label) { onCheckIn(.skipped) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("checkIn.skipped")
        }
        .accessibilityIdentifier("plannedDate.checkIn")
    }
}

/// Pick a day and time for a date at the suggested place.
struct DatePlanSheet: View {
    let place: String
    let name: String
    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var when: Date = DatePlanSheet.defaultTime

    /// Tomorrow at 19:30.
    static var defaultTime: Date {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        return Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: tomorrow) ?? tomorrow
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(place).font(.glimpseTitle2)
                Text("\(name) gets your suggestion and can say yes or pick another time.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                DatePicker(
                    "When",
                    selection: $when,
                    in: Date.now.addingTimeInterval(30 * 60)...Date.now.addingTimeInterval(21 * 86_400),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(Palette.mint)
                Button("Suggest this time") {
                    onPick(when)
                    dismiss()
                }
                .buttonStyle(.glimpse)
                .accessibilityIdentifier("datePlan.suggest")
            }
            .padding(20)
            .background(Palette.midnight)
            .navigationTitle("Plan a date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
