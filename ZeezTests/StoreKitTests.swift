import Foundation
import Testing
import StoreKit
import StoreKitTest
@testable import Zeez

/// Locator class so the .storekit resource can be found in the test bundle.
private final class StoreKitTestsBundleLocator {}

@Suite("StoreKit correctness (2.1)", .serialized)
struct StoreKitTests {

    // MARK: - Tier mapping (pure, no StoreKit runtime)

    @Test func premiumPlusIdentifiersResolveToPremiumPlus() {
        // Regression: contains-matching resolved "…premiumplus…" to .premium because
        // the identifier contains "premium". Mapping must be exact-match.
        #expect(StoreKitManager.subscriptionTier(from: "com.zeez.subscription.premiumplus.monthly") == .premium_plus)
        #expect(StoreKitManager.subscriptionTier(from: "com.zeez.subscription.premiumplus.annual") == .premium_plus)
    }

    @Test func premiumIdentifiersResolveToPremium() {
        #expect(StoreKitManager.subscriptionTier(from: "com.zeez.subscription.premium.monthly") == .premium)
        #expect(StoreKitManager.subscriptionTier(from: "com.zeez.subscription.premium.annual") == .premium)
    }

    @Test func nonProductIdentifiersResolveToNil() {
        #expect(StoreKitManager.subscriptionTier(from: "com.zeez.subscription.premium") == nil)
        #expect(StoreKitManager.subscriptionTier(from: "com.zeez.subscription.basic.monthly") == nil)
        #expect(StoreKitManager.subscriptionTier(from: "") == nil)
    }

    @Test func everyPaidTierHasMonthlyAndAnnualProducts() {
        for tier in SubscriptionTier.allCases {
            #expect(StoreKitManager.productIDs.contains { $0.tier == tier && !$0.annual })
            #expect(StoreKitManager.productIDs.contains { $0.tier == tier && $0.annual })
        }
        // Product IDs must be unique.
        #expect(Set(StoreKitManager.productIDs.map(\.id)).count == StoreKitManager.productIDs.count)
    }

    @Test func tierOrderingUsesNumericRank() {
        // Regression: ordering used raw-string comparison ("Premium+" > "Premium" by luck).
        #expect(SubscriptionTier.premium_plus > .premium)
        #expect(SubscriptionTier.premium > .basic)
        #expect([SubscriptionTier.premium, .basic, .premium_plus].max() == .premium_plus)
    }

    // MARK: - Cached tier persistence

    @Test @MainActor func cachedTierSurvivesReload() {
        let previous = UserDefaults.standard.string(forKey: "subscription_tier")
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: "subscription_tier")
            } else {
                UserDefaults.standard.removeObject(forKey: "subscription_tier")
            }
            PremiumManager.shared.reset()
        }

        PremiumManager.shared.updateSubscription(.premium_plus)
        // reset() re-reads persisted state, simulating a fresh launch.
        PremiumManager.shared.reset()
        #expect(PremiumManager.shared.activeSubscription == .premium_plus)
    }

    // MARK: - StoreKitTest-backed entitlement flows

    @MainActor
    private func makeSession() throws -> SKTestSession {
        let bundle = Bundle(for: StoreKitTestsBundleLocator.self)
        let url = try #require(bundle.url(forResource: "Zeez", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    /// Clears test-session transactions and re-syncs manager + persisted tier to empty.
    @MainActor
    private func cleanUp(_ session: SKTestSession) async {
        session.clearTransactions()
        await StoreKitManager.shared.updatePurchasedSubscriptions()
        UserDefaults.standard.removeObject(forKey: "subscription_tier")
        PremiumManager.shared.reset()
    }

    /// SKTestSession state changes (buy/expire) apply asynchronously to the
    /// entitlement stream, so assertions use confirmation-based waiting: re-run
    /// updatePurchasedSubscriptions until the expected tier appears or timeout.
    @MainActor
    private func waitForTier(_ expected: SubscriptionTier?, timeout: TimeInterval = 5) async -> SubscriptionTier? {
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            await StoreKitManager.shared.updatePurchasedSubscriptions()
            if PremiumManager.shared.activeSubscription == expected || Date() >= deadline {
                return PremiumManager.shared.activeSubscription
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    @Test @MainActor func purchaseGrantsEntitledTier() async throws {
        let session = try makeSession()
        _ = try await session.buyProduct(identifier: "com.zeez.subscription.premium.monthly")
        #expect(await waitForTier(.premium) == .premium)
        await cleanUp(session)
    }

    @Test @MainActor func entitlementResolvesWithoutLoadedProducts() async throws {
        // Regression: entitlements used to resolve via the in-memory `subscriptions`
        // array, so an offline launch (loadProducts() failed) persisted a wrongful
        // downgrade. The tier must come from the productID alone — no loadProducts()
        // call happens anywhere in this test.
        let session = try makeSession()
        _ = try await session.buyProduct(identifier: "com.zeez.subscription.premiumplus.annual")
        #expect(await waitForTier(.premium_plus) == .premium_plus)
        await cleanUp(session)
    }

    @Test @MainActor func upgradeResolvesToHighestTier() async throws {
        let session = try makeSession()
        _ = try await session.buyProduct(identifier: "com.zeez.subscription.premium.monthly")
        _ = try await session.buyProduct(identifier: "com.zeez.subscription.premiumplus.monthly")
        #expect(await waitForTier(.premium_plus) == .premium_plus)
        await cleanUp(session)
    }

    @Test @MainActor func expiryDowngrades() async throws {
        let session = try makeSession()
        _ = try await session.buyProduct(identifier: "com.zeez.subscription.premium.monthly")
        #expect(await waitForTier(.premium) == .premium)

        try session.expireSubscription(productIdentifier: "com.zeez.subscription.premium.monthly")
        #expect(await waitForTier(nil) == nil)
        await cleanUp(session)
    }
}
