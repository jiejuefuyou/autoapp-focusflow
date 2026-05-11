import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class IAPManager {
    static let premiumProductID = "com.jiejuefuyou.focusflow.premium"

    var isPremium: Bool = false
    var products: [Product] = []
    var purchaseInProgress: Bool = false
    var lastError: String?

    private nonisolated(unsafe) var listenerTask: Task<Void, Never>?

    init() {
        listenerTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let t) = update else { continue }
                await t.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    deinit { listenerTask?.cancel() }

    func refresh() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.premiumProductID])
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product = products.first(where: { $0.id == Self.premiumProductID }) else {
            await loadProducts()
            return
        }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let t) = verification {
                    await t.finish()
                }
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               t.productID == Self.premiumProductID,
               t.revocationDate == nil {
                entitled = true
            }
        }
        isPremium = entitled
    }
}
