import Foundation
import CoreData
import os.log

/// Tracks subscription-related events and metrics
class SubscriptionEvents {
    static let shared = SubscriptionEvents()
    
    private let context: NSManagedObjectContext
    private var backgroundContext: NSManagedObjectContext
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
        self.backgroundContext = PersistenceController.shared.container.newBackgroundContext()
    }
    
    // MARK: - Subscription Events
    
    func trackSubscriptionStarted(
        tier: SubscriptionTier,
        isAnnual: Bool,
        source: SubscriptionSource
    ) {
        createSubscriptionEvent(
            type: "started",
            tier: tier.rawValue,
            isAnnual: isAnnual,
            source: source.rawValue
        )
    }
    
    func trackSubscriptionCancelled(
        tier: SubscriptionTier,
        reason: CancellationReason?
    ) {
        createSubscriptionEvent(
            type: "cancelled",
            tier: tier.rawValue,
            cancellationReason: reason?.rawValue
        )
    }
    
    func trackSubscriptionRenewed(tier: SubscriptionTier) {
        createSubscriptionEvent(
            type: "renewed",
            tier: tier.rawValue
        )
    }
    
    // MARK: - Feature Events
    
    func trackFeatureAccessed(_ feature: PremiumFeature) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            let record = FeatureAccessRecord(context: self.backgroundContext)
            record.id = UUID()
            record.timestamp = Date()
            record.feature = feature.rawValue
            
            // Add session context if available
            if let activeSession = try? self.backgroundContext.fetch(SleepSession.fetchRequest())
                .first(where: { $0.isActive }) {
                record.session = activeSession
            }
            
            try? self.backgroundContext.save()
        }
    }
    
    // MARK: - Upgrade Events
    
    func trackUpgradeImpression(
        feature: PremiumFeature,
        source: String
    ) {
        createUpgradeEvent(
            type: "impression",
            feature: feature.rawValue,
            source: source
        )
    }
    
    func trackUpgradeButtonTapped(
        feature: PremiumFeature,
        source: String
    ) {
        createUpgradeEvent(
            type: "button_tapped",
            feature: feature.rawValue,
            source: source
        )
    }
    
    // MARK: - Private Methods
    
    private func createSubscriptionEvent(
        type: String,
        tier: String,
        isAnnual: Bool = false,
        source: String? = nil,
        cancellationReason: String? = nil
    ) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            let record = SubscriptionEventRecord(context: self.backgroundContext)
            record.id = UUID()
            record.timestamp = Date()
            record.eventType = type
            record.tier = tier
            record.isAnnual = isAnnual
            record.source = source
            record.cancellationReason = cancellationReason
            
            // Add session context if available
            if let activeSession = try? self.backgroundContext.fetch(SleepSession.fetchRequest())
                .first(where: { $0.isActive }) {
                record.session = activeSession
            }
            
            try? self.backgroundContext.save()
        }
    }
    
    private func createUpgradeEvent(
        type: String,
        feature: String,
        source: String
    ) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            let record = UpgradeEventRecord(context: self.backgroundContext)
            record.id = UUID()
            record.timestamp = Date()
            record.eventType = type
            record.feature = feature
            record.source = source
            
            // Add session context if available
            if let activeSession = try? self.backgroundContext.fetch(SleepSession.fetchRequest())
                .first(where: { $0.isActive }) {
                record.session = activeSession
            }
            
            try? self.backgroundContext.save()
        }
    }
}

// MARK: - Supporting Types

enum SubscriptionSource: String {
    case featureGate = "feature_gate"
    case settings = "settings"
    case onboarding = "onboarding"
    case deepLink = "deep_link"
}

enum CancellationReason: String {
    case cost = "cost"
    case useFrequency = "use_frequency"
    case features = "features"
    case technical = "technical"
    case other = "other"
}
