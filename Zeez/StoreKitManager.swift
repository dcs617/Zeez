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
    
    /// Restore purchases
    func restorePurchases() async throws {
        try? await AppStore.sync()
        await updatePurchasedSubscriptions()
    }
    
    /// Get product for subscription tier
    func product(for tier: SubscriptionTier, annual: Bool = false) -> Product? {
        return subscriptions.first { product in
            product.id == productIdentifier(for: tier, annual: annual)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadProducts() async {
        do {
            let identifiers = SubscriptionTier.allCases.flatMap { tier in
                [
                    productIdentifier(for: tier, annual: false),
                    productIdentifier(for: tier, annual: true)
                ]
            }
            
            let products = try await Product.products(for: identifiers)
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
    
    private func updatePurchasedSubscriptions() async {
        var purchased: [Product] = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if let subscription = subscriptions.first(where: { $0.id == transaction.productID }) {
                    purchased.append(subscription)
                }
            } catch {
                ZeezLogger.error(ZeezLogger.app, "Failed to verify transaction", error: error)
            }
        }
        
        self.purchasedSubscriptions = purchased
        
        // Update PremiumManager with active subscription
        if let highestTier = purchased
            .compactMap({ subscriptionTier(from: $0.id) })
            .sorted(by: { $0.rawValue > $1.rawValue })
            .first {
            PremiumManager.shared.updateSubscription(highestTier)
        } else {
            PremiumManager.shared.updateSubscription(nil)
        }
    }
    
    private func productIdentifier(for tier: SubscriptionTier, annual: Bool) -> String {
        "com.zeez.subscription.\(tier.rawValue.lowercased()).\(annual ? "annual" : "monthly")"
    }
    
    private func subscriptionTier(from identifier: String) -> SubscriptionTier? {
        for tier in SubscriptionTier.allCases {
            if identifier.contains(tier.rawValue.lowercased()) {
                return tier
            }
        }
        return nil
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
