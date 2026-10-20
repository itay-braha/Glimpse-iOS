import SwiftUI

/// Coffee deals near me, and the walk-in flow. Opened from Connections.
struct DealsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var model = DealsModel()

    var body: some View {
        NavigationStack {
            content
                .background(Palette.midnight)
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        if model.step == .list {
                            Button("Close") { dismiss() }
                        } else if !isOnPass {
                            Button("Back", systemImage: "chevron.backward") { model.backToList() }
                        }
                    }
                }
        }
        .task {
            await model.load(using: app.backend)
            await model.logViews(using: app.backend)
        }
        .interactiveDismissDisabled(isOnPass)
        .alert("Couldn't do that", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var isOnPass: Bool {
        if case .pass = model.step { return true }
        return false
    }

    private var navigationTitle: String {
        switch model.step {
        case .list: String(localized: "Coffee deals")
        default: ""
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .list:
            list
        case .checking(let deal):
            VStack(spacing: 14) {
                ProgressView().tint(Palette.mint)
                Text("Checking you're at \(deal.place)…")
                    .font(.glimpseHeadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .confirm(let deal, let band):
            DealConfirmView(deal: deal) {
                Task { await model.confirmHere(deal, band: band, using: app.backend) }
            } onElsewhere: {
                Task { await model.notHere(deal, band: band, using: app.backend) }
            }
        case .choose(let deal):
            DealChooseView(places: model.otherPlaces(than: deal)) { other in
                Task { await model.choose(other, using: app.backend) }
            }
        case .pass(let deal, let pass):
            DealPassView(deal: deal, pass: pass) {
                await model.redeem(deal, pass: pass, using: app.backend)
            } onClose: {
                model.backToList()
            }
        case .unavailable(let result):
            DealUnavailableView(result: result, others: model.otherPlaces(than: result.deal)) { other in
                Task { await model.start(other, using: app.backend, checkLocation: !app.isDemo) }
            } onDone: {
                model.backToList()
            }
        case .redeemed(let deal, let at):
            DealRedeemedView(deal: deal, at: at, name: app.profile?.displayName ?? "") {
                model.backToList()
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(model.deals) { deal in
                    Button {
                        Task { await model.start(deal, using: app.backend, checkLocation: !app.isDemo) }
                    } label: {
                        DealRow(deal: deal)
                    }
                    .buttonStyle(.plain)
                    .disabled(deal.state != .available)
                    .accessibilityIdentifier("deal.\(deal.id.uuidString)")
                }
            } footer: {
                Text("Show the pass at the counter and staff tap Redeem on your phone. We only check you're nearby, on your phone; your exact location is never sent.")
            }
            if model.hasLoaded && model.deals.isEmpty {
                ContentUnavailableView("No deals near you yet", systemImage: "cup.and.saucer",
                                       description: Text("We're adding places in Tel Aviv. Check back soon."))
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .listRowBackground(Palette.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deals.list")
    }
}

private struct DealRow: View {
    let deal: Deal

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: deal.category?.symbol ?? "cup.and.saucer.fill")
                .font(.title3)
                .foregroundStyle(Palette.onMint)
                .frame(width: 44, height: 44)
                .background(deal.state == .available ? Palette.mint : Palette.surfaceRaised, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(deal.title)
                    .font(.glimpseHeadline)
                    .foregroundStyle(deal.state == .available ? Palette.textPrimary : Palette.textSecondary)
                Text(deal.place)
                    .font(.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                HStack(spacing: 8) {
                    if let distance = deal.distanceLabel {
                        Text(distance)
                    }
                    stateChip
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textTertiary)
            }
            Spacer(minLength: 0)
            if deal.state == .available {
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.top, 14)
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var stateChip: some View {
        switch deal.state {
        case .available:
            if let remaining = deal.remaining {
                Text("Only \(remaining) left").foregroundStyle(Palette.amber)
            }
        case .soldOut:
            Text("All given out")
        case .used:
            if let again = deal.availableAgainAt {
                Text("Used · back \(again.formatted(.dateTime.weekday(.wide)))")
            } else {
                Text("Used")
            }
        case .ended:
            Text("Ended")
        }
    }
}

/// "Are you at <place>?" when the phone couldn't tell (or location is off).
private struct DealConfirmView: View {
    let deal: Deal
    let onHere: () -> Void
    let onElsewhere: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Image(systemName: "mappin.and.ellipse")
                .font(.largeTitle)
                .foregroundStyle(Palette.mint)
            Text("Are you at \(deal.place)?")
                .font(.glimpseTitle)
                .foregroundStyle(Palette.textPrimary)
            Text("We couldn't tell from here, and that's fine. The deal works at the counter there.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Button("Yes, I'm here", systemImage: "checkmark", action: onHere)
                .buttonStyle(GlimpseButtonStyle(kind: .primary))
                .accessibilityIdentifier("deal.imHere")
            Button("I'm somewhere else", action: onElsewhere)
                .buttonStyle(GlimpseButtonStyle(kind: .secondary))
                .accessibilityIdentifier("deal.elsewhere")
        }
        .padding(24)
    }
}

/// "Choose where I am": other places with a deal, nearest first.
private struct DealChooseView: View {
    let places: [Deal]
    let onPick: (Deal) -> Void

    var body: some View {
        List {
            Section("Where are you?") {
                ForEach(places) { deal in
                    Button { onPick(deal) } label: { DealRow(deal: deal) }
                        .buttonStyle(.plain)
                }
            }
            if places.isEmpty {
                Text("No other deals nearby right now.")
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// All given out, used recently, or ended: said kindly, with somewhere else to go.
private struct DealUnavailableView: View {
    let result: DealOpenResult
    let others: [Deal]
    let onOther: (Deal) -> Void
    let onDone: () -> Void

    private var title: String {
        switch result.status {
        case .soldOut: String(localized: "That's everyone for now")
        case .used: String(localized: "You've used this one")
        default: String(localized: "This deal has ended")
        }
    }

    private var message: String {
        switch result.status {
        case .soldOut:
            String(localized: "\(result.deal.place) has given away all its Glimpse deals. Thanks for stopping by, and enjoy your visit anyway.")
        case .used:
            if let again = result.deal.availableAgainAt {
                String(localized: "It comes back on \(again.formatted(.dateTime.weekday(.wide).day().month())). Here's what else is near you.")
            } else {
                String(localized: "It comes back in a few days. Here's what else is near you.")
            }
        default:
            String(localized: "\(result.deal.place) isn't running it any more. Here's what else is near you.")
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.title)
                        .foregroundStyle(Palette.amber)
                    Text(title).font(.glimpseTitle2).foregroundStyle(Palette.textPrimary)
                    Text(message).font(.subheadline).foregroundStyle(Palette.textSecondary)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("deal.unavailable")
            }
            .listRowBackground(Color.clear)
            if !others.isEmpty {
                Section("Nearby") {
                    ForEach(others.prefix(3)) { deal in
                        Button { onOther(deal) } label: { DealRow(deal: deal) }
                            .buttonStyle(.plain)
                    }
                }
            }
            Section {
                Button("Back to deals", action: onDone)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

private struct DealRedeemedView: View {
    let deal: Deal
    let at: Date
    let name: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Palette.mint)
                .symbolEffect(.bounce, value: at)
            Text("Enjoy, \(name)!")
                .font(.glimpseTitle)
                .foregroundStyle(Palette.textPrimary)
            Text("Redeemed at \(deal.place) · \(at.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Done", action: onDone)
                .buttonStyle(GlimpseButtonStyle(kind: .primary))
        }
        .padding(24)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("deal.redeemed")
    }
}
