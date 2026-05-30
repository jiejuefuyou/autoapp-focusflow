import Foundation
import StoreKit
import Observation

// MARK: - PurchaseState

/// Explicit state for every purchase outcome — never silent.
/// Per CLAUDE.md round-4 lesson: each state must have visible UI surface.
enum PurchaseState: Equatable {
    case idle
    case purchasing
    case success
    case failed(String)
    case cancelled
    case pending
    case unverified
}

// MARK: - IAPManager

@MainActor
@Observable
final class IAPManager {
    static let premiumProductID = "com.jiejuefuyou.focusflow.premium"

    /// UserDefaults key for cached premium state — avoids the "Unlock" CTA
    /// flash on cold start while StoreKit refreshes the live entitlement
    /// (parity with AutoChoice/WaterNow/DaysUntil IAPManager).
    private static let cachedIsPremiumKey = "FocusFlow.iap.cachedIsPremium"

    var isPremium:     Bool         = UserDefaults.standard.bool(forKey: IAPManager.cachedIsPremiumKey)
    var products:      [Product]    = []
    var purchaseState: PurchaseState = .idle

    // Legacy accessor kept for backward compat — computed from state
    var purchaseInProgress: Bool { purchaseState == .purchasing }

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
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func purchase() async {
        guard let product = products.first(where: { $0.id == Self.premiumProductID }) else {
            purchaseState = .failed(String(localized: "Product unavailable. Tap Restore or try again."))
            await loadProducts()
            return
        }
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let t):
                    await t.finish()
                    await refreshEntitlements()
                    purchaseState = .success
                case .unverified:
                    purchaseState = .unverified
                }
            case .userCancelled:
                purchaseState = .cancelled
            case .pending:
                purchaseState = .pending
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    func restore() async {
        purchaseState = .purchasing
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = isPremium ? .success : .idle
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
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
        UserDefaults.standard.set(entitled, forKey: Self.cachedIsPremiumKey)
    }
}
