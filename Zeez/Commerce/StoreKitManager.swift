import StoreKit
import Foundation
import os.log

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    @Published private(set) var subscriptions: [Product] = []
    @Published private(set) var purchasedSubscriptions: [Product] = []
    
    private var transactionListener: Task<Void, Error>?
    
    private init() {
        transactionListener = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedSubscriptions()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Purchase a subscription
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedSubscriptions()
            await transaction.finish()
            return transaction
            
        case .userCancelled:
            return nil
            
        case .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    /// Restore purchases. Throws if the App Store sync fails so the UI never
    /// reports "restored" after a failed sync.
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedSubscriptions()
    }
    
    /// Get product for subscription tier
    func product(for tier: SubscriptionTier, annual: Bool = false) -> Product? {
        return subscriptions.first { product in
            product.id == productIdentifier(for: tier, annual: annual)
        }
    }
    
    // MARK: - Product Identifiers

    /// Product IDs must match App Store Connect character-for-character (mirrored in
    /// `ZeezTests/Zeez.storekit`). Note "+" is not a valid product-ID character, so
    /// premium_plus uses "premiumplus". ⚠️ Confirm these against ASC before release.
    nonisolated static let productIDs: [(tier: SubscriptionTier, annual: Bool, id: String)] = [
        (.premium, false, "com.zeez.subscription.premium.monthly"),
        (.premium, true, "com.zeez.subscription.premium.annual"),
        (.premium_plus, false, "com.zeez.subscription.premiumplus.monthly"),
        (.premium_plus, true, "com.zeez.subscription.premiumplus.annual")
    ]

    private func productIdentifier(for tier: SubscriptionTier, annual: Bool) -> String? {
        Self.productIDs.first { $0.tier == tier && $0.annual == annual }?.id
    }

    /// Exact-match lookup. Never use substring matching here: every premium_plus
    /// identifier *contains* "premium", which used to resolve Premium+ entitlements
    /// to the lower tier.
    nonisolated static func subscriptionTier(from identifier: String) -> SubscriptionTier? {
        productIDs.first { $0.id == identifier }?.tier
    }

    // MARK: - Internal Methods (internal for tests — production callers stay in this file)

    func loadProducts() async {
        do {
            let products = try await Product.products(for: Self.productIDs.map(\.id))
            subscriptions = products.sorted { $0.price < $1.price }
        } catch {
            ZeezLogger.error(ZeezLogger.app, "Failed to load products", error: error)
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchasedSubscriptions()
                    await transaction.finish()
                } catch {
                    ZeezLogger.error(ZeezLogger.app, "Transaction failed verification", error: error)
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    func updatePurchasedSubscriptions() async {
        var purchased: [Product] = []
        var entitledTiers: [SubscriptionTier] = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                // Map the tier straight from the productID — entitlements must resolve
                // even when loadProducts() failed (e.g. offline launch), otherwise a
                // valid subscriber gets a persisted downgrade.
                if let tier = Self.subscriptionTier(from: transaction.productID) {
                    entitledTiers.append(tier)
                }
                if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
                    purchased.append(subscription)
                }
            } catch {
                ZeezLogger.error(ZeezLogger.app, "Failed to verify transaction", error: error)
            }
        }

        self.purchasedSubscriptions = purchased

        // Update PremiumManager with the highest active tier (numeric rank, not raw string)
        PremiumManager.shared.updateSubscription(entitledTiers.max())
    }
}

enum StoreError: Error {
    case failedVerification
}

extension SubscriptionTier: CaseIterable {
    static var allCases: [SubscriptionTier] {
        [.premium, .premium_plus]
    }
}
