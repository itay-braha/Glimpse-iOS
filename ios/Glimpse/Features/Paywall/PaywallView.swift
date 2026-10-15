import StoreKit
import SwiftUI

/// Glimpse+ upsell. Sells convenience and curiosity, never more connections:
/// the 20-match cap applies to everyone.
struct PaywallView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let reason: PaywallReason

    @State private var quota: LikeQuota?
    @State private var legal: LegalDocument?

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
                            Text("Glimpse+")
                                .font(.glimpseTitle)
                                .foregroundStyle(Palette.brandGradient)
                        }
                        Text(headline)
                            .heroFont()
                            .minimumScaleFactor(0.6)
                            .foregroundStyle(Palette.textPrimary)
                        if reason == .outOfLikes, let resets = quota?.resetsAt {
                            Text("Free likes refill \(resets, format: .relative(presentation: .named)).")
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Benefit(symbol: "heart.fill", title: "Unlimited likes", detail: "Keep exploring without a daily limit.")
                        Benefit(symbol: "eye.fill", title: "See everyone who liked you", detail: "No blur, no waiting for tomorrow's reveal.")
                        Benefit(symbol: "bolt.heart.fill", title: "Answer instantly", detail: "Like back from your list, and it's a match.")
                        Benefit(symbol: "rectangle.stack.fill", title: "150 new profiles a day", detail: "Three times the daily glimpses.")
                        Benefit(symbol: "snowflake", title: "Freeze up to 3 connections", detail: "Protect your favorites from auto-release.")
                        Benefit(symbol: "arrow.uturn.backward.circle.fill", title: "Second chances", detail: "Ask a released connection to reconnect, once a week.")
                        Benefit(symbol: "circle.dashed", title: "Same 20-connection circle", detail: "Some things aren't for sale. Real conversations still win.")
                    }
                    .padding(18)
                    .background(Palette.surface.opacity(0.85), in: .rect(cornerRadius: 22))

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
            quota = try? await app.backend.likeQuota()
            app.track("paywall_viewed", ["reason": reason.rawValue])
        }
        .sheet(item: $legal) { document in
            LegalDocumentView(document: document)
        }
    }

    private var headline: String {
        switch reason {
        case .outOfLikes: "You're on a roll."
        case .outOfViews: "See more people today."
        case .likedYou: "See who wants to see more."
        case .freeze: "Protect the ones that matter."
        case .secondChance: "Everyone deserves a second chance."
        case .settings: "More glimpses, less waiting."
        }
    }

    @ViewBuilder
    private var plans: some View {
        if app.isDemo || store.products.isEmpty {
            VStack(spacing: 10) {
                Button {
                    Task {
                        if await store.purchaseDemo(backend: app.backend) { finish() }
                    }
                } label: {
                    Text(app.isDemo ? "Try Glimpse+ (demo)" : "Glimpse+ isn't available yet")
                }
                .buttonStyle(.glimpse)
                .disabled(!app.isDemo)
                if store.isLoading { ProgressView() }
            }
        } else {
            VStack(spacing: 10) {
                ForEach(store.products, id: \.id) { product in
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
            app.track("plus_purchased", ["product": product.id])
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
                Text(title).font(.glimpseHeadline)
                Text(detail).font(.subheadline).foregroundStyle(Palette.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
