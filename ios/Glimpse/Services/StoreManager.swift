import Foundation
import Observation
import StoreKit

/// Glimpse+ subscriptions with StoreKit 2. Every transaction is re-verified by
/// the `verify-purchase` function, which owns the entitlement, so a tampered
/// client can't grant itself Plus.
@MainActor
@Observable
final class StoreManager {
    static let productIDs = ["com.itaybraha.glimpse.plus.monthly", "com.itaybraha.glimpse.plus.yearly"]

    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        let loaded = (try? await Product.products(for: Self.productIDs)) ?? []
        products = loaded.sorted { $0.price < $1.price }
    }

    /// Listens for renewals, Ask to Buy approvals and purchases made on other devices.
    func startListening(backend: any GlimpseBackend) {
        guard updatesTask == nil, !backend.isDemo else { return }
        updatesTask = Task {
            for await update in Transaction.updates {
                if case let .verified(transaction) = update {
                    _ = try? await backend.verifyPurchase(signedTransaction: update.jwsRepresentation)
                    await transaction.finish()
                }
            }
        }
    }

    /// Returns true when Glimpse+ is active afterwards.
    func purchase(_ product: Product, accountID: UUID, backend: any GlimpseBackend) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase(options: [.appAccountToken(accountID)])
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    errorMessage = "The App Store couldn't verify this purchase."
                    return false
                }
                let active = try await backend.verifyPurchase(signedTransaction: verification.jwsRepresentation)
                await transaction.finish()
                return active
            case .pending:
                errorMessage = "Your purchase is waiting for approval."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = GlimpseError.describe(error)
            return false
        }
    }

    /// Demo builds have no App Store products; unlock Plus locally so the flow can be tried.
    func purchaseDemo(backend: any GlimpseBackend) async -> Bool {
        (try? await backend.verifyPurchase(signedTransaction: "demo")) ?? false
    }

    func restore(backend: any GlimpseBackend) async -> Bool {
        try? await AppStore.sync()
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified = result,
               (try? await backend.verifyPurchase(signedTransaction: result.jwsRepresentation)) == true {
                active = true
            }
        }
        if !active { errorMessage = "No active Glimpse+ subscription was found." }
        return active
    }
}
