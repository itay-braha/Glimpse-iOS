import StoreKit
import SwiftUI

/// Glimpse+ and Glimpse Gold upsell. Sells convenience and curiosity, never more
/// connections: the 15-match cap, 10 daily likes, "Liked you" and every safety
/// feature are the same for everyone.
struct PaywallView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let reason: PaywallReason

    @State private var legal: LegalDocument?
    @State private var tier: MembershipTier

    init(reason: PaywallReason) {
        self.reason = reason
        _tier = State(initialValue: reason == .gold ? .gold : .plus)
    }

    private var store: StoreManager { app.store }

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Spacer()
                        Button("Close", systemImage: "xmark") { dismiss() }
                            .labelStyle(.iconOnly)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: .circle)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            LogoMark(size: 34)
                            Text(tier.title)
                                .font(.glimpseTitle)
                                .foregroundStyle(tier == .gold ? AnyShapeStyle(Palette.amber) : AnyShapeStyle(Palette.brandGradient))
                        }
                        Text(headline)
                            .heroFont()
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(Palette.textPrimary)
                    }

                    Picker("Plan", selection: $tier) {
                        ForEach(MembershipTier.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("paywall.tier")

                    VStack(alignment: .leading, spacing: 16) {
                        if tier == .gold {
                            Benefit(symbol: "sparkles", title: "Everything in Glimpse+", detail: "150 profiles a day, 3 freezes, second chances.")
                            Benefit(symbol: "sun.max.fill", title: "Weekly Spotlight", detail: "Once a week, 30 minutes near the front for people who'd likely like you, inside their own filters.")
                            Benefit(symbol: "chart.bar.fill", title: "Clip insights", detail: "See which of your clips get watched through, skipped or liked. Totals only, never who.")
                            Benefit(symbol: "airplane", title: "Travel mode", detail: "Show up in an open city before you get there, for up to 14 days.")
                            Benefit(symbol: "arrow.uturn.backward", title: "Rewind", detail: "Passed too fast? Bring the last person back, 5 times a day.")
                        } else {
                            Benefit(symbol: "rectangle.stack.fill", title: "150 new profiles a day", detail: "Three times the daily glimpses.")
                            Benefit(symbol: "snowflake", title: "Freeze up to 3 connections", detail: "Protect your favorites from auto-release.")
                            Benefit(symbol: "arrow.uturn.backward.circle.fill", title: "Second chances", detail: "Ask a released connection to reconnect, once a week.")
                        }
                        Benefit(symbol: "circle.dashed", title: "Same 15-connection circle, same 10 likes", detail: "Some things aren't for sale. Real conversations and safety are the same for everyone.")
                    }
                    .padding(18)
                    .background(Palette.surface.opacity(0.85), in: .rect(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(tier == .gold ? Palette.amber.opacity(0.6) : .clear))

                    plans

                    if let error = store.errorMessage {
                        ErrorText(error)
                    }

                    footer
                }
                .padding(20)
            }
        }
        .task {
            await store.loadProducts()
            app.track("paywall_viewed", ["reason": reason.rawValue])
        }
        .sheet(item: $legal) { document in
            LegalDocumentView(document: document)
        }
    }

    private var headline: String {
        switch reason {
        case .outOfViews: String(localized: "See more people today.")
        case .gold: tier == .gold ? String(localized: "Be seen. Go further.") : String(localized: "More glimpses, less waiting.")
        case .freeze: String(localized: "Protect the ones that matter.")
        case .secondChance: String(localized: "Everyone deserves a second chance.")
        case .settings: String(localized: "More glimpses, less waiting.")
        }
    }

    @ViewBuilder
    private var plans: some View {
        if app.isDemo || store.products(for: tier).isEmpty {
            VStack(spacing: 10) {
                Button {
                    Task {
                        if await store.purchaseDemo(tier, backend: app.backend) { finish() }
                    }
                } label: {
                    Text(app.isDemo ? String(localized: "Try \(tier.title) (demo)") : String(localized: "\(tier.title) isn't available yet"))
                }
                .buttonStyle(.glimpse)
                .disabled(!app.isDemo)
                .accessibilityIdentifier("paywall.buy")
                Text(tier.placeholderPrice)
                    .font(.caption)
                    .foregroundStyle(Palette.textTertiary)
                if store.isLoading { ProgressView() }
            }
        } else {
            VStack(spacing: 10) {
                ForEach(store.products(for: tier), id: \.id) { product in
                    Button {
                        Task { await buy(product) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.displayName).font(.glimpseHeadline)
                                Text(product.description).font(.caption)
                            }
                            Spacer()
                            Text(product.displayPrice).font(.glimpseHeadline)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(GlimpseButtonStyle(kind: product.id.hasSuffix("yearly") ? .primary : .secondary))
                    .disabled(store.isPurchasing)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button("Restore purchases") {
                Task {
                    if await store.restore(backend: app.backend) { finish() }
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.textSecondary)

            Text("Subscriptions renew automatically until cancelled in your Apple ID settings at least 24 hours before the period ends.")
                .font(.caption2)
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Terms") { legal = .terms }
                Button("Privacy") { legal = .privacy }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func buy(_ product: Product) async {
        guard let accountID = app.profile?.id else { return }
        if await store.purchase(product, accountID: accountID, backend: app.backend) {
            app.track(tier == .gold ? "gold_purchased" : "plus_purchased", ["product": product.id])
            finish()
        }
    }

    private func finish() {
        app.matchesDidChange()
        dismiss()
    }
}

private struct Benefit: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Palette.brandGradient)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).font(.glimpseHeadline)
                Text(LocalizedStringKey(detail)).font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
