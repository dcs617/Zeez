import Foundation
import os.log

/// Defines and manages premium features in the app
enum PremiumFeature: String, CaseIterable {
    case extendedHistory = "Extended Sleep History"
    case detailedSleepStages = "Detailed Sleep Stage Analysis"
    case environmentalReports = "Environmental Impact Reports"
    case advancedAlarms = "Advanced Smart Alarms"
    case sleepCoaching = "Personal Sleep Coaching"
    case dataExport = "Data Export"
    case customSounds = "Custom Alarm Sounds"
    case heartRateAnalysis = "Heart Rate Analysis"
    case environmentalAnalysis = "Environmental Analysis"
    
    var description: String {
        switch self {
        case .extendedHistory:
            return "Access your complete sleep history and long-term trends"
        case .detailedSleepStages:
            return "In-depth analysis of your sleep cycles and stages"
        case .environmentalReports:
            return "Detailed reports on how your environment affects sleep"
        case .advancedAlarms:
            return "Enhanced smart wake features and custom wake windows"
        case .sleepCoaching:
            return "Personalized recommendations and coaching"
        case .dataExport:
            return "Export your sleep data for external analysis"
        case .customSounds:
            return "Use your own sounds for alarms and notifications"
        case .heartRateAnalysis:
            return "Real-time heart rate monitoring and advanced analytics"
        case .environmentalAnalysis:
            return "Live environmental impact tracking and optimization"
        }
    }
    
    var iconName: String {
        switch self {
        case .extendedHistory: return "clock.arrow.circlepath"
        case .detailedSleepStages: return "chart.xyaxis.line"
        case .environmentalReports: return "leaf"
        case .advancedAlarms: return "alarm"
        case .sleepCoaching: return "person.fill.checkmark"
        case .dataExport: return "square.and.arrow.up"
        case .customSounds: return "music.note"
        case .heartRateAnalysis: return "heart.text.square"
        case .environmentalAnalysis: return "leaf.circle"
        }
    }
}

/// Manages premium feature access and subscription state
class PremiumManager: ObservableObject {
    static let shared = PremiumManager()
    
    @Published private(set) var activeSubscription: SubscriptionTier?
    @Published private(set) var availableFeatures: Set<PremiumFeature> = []
    
    private init() {
        loadSubscriptionState()
    }
    
    /// Check if a specific feature is available
    func hasAccess(to feature: PremiumFeature) -> Bool {
        guard activeSubscription != nil else { return false }
        return availableFeatures.contains(feature)
    }
    
    /// Track feature access attempt
    func trackAccess(to feature: PremiumFeature, in source: String) {
        if hasAccess(to: feature) {
            SubscriptionEvents.shared.trackFeatureAccessed(feature)
        } else {
            SubscriptionEvents.shared.trackUpgradeImpression(
                feature: feature,
                source: source
            )
        }
    }
    
    /// Get features available for a subscription tier
    func features(for tier: SubscriptionTier) -> [PremiumFeature] {
        switch tier {
        case .basic:
            return []
        case .premium:
            return [.extendedHistory, .detailedSleepStages, .environmentalReports, .heartRateAnalysis, .environmentalAnalysis]
        case .premium_plus:
            return PremiumFeature.allCases
        }
    }
    
    /// Update subscription status
    func updateSubscription(_ tier: SubscriptionTier?) {
        let oldTier = activeSubscription
        self.activeSubscription = tier
        
        if let tier = tier {
            self.availableFeatures = Set(features(for: tier))
            
            // Track subscription change
            if oldTier != tier {
                SubscriptionEvents.shared.trackSubscriptionStarted(
                    tier: tier,
                    isAnnual: false, // Update this based on actual subscription
                    source: .settings
                )
            }
        } else {
            self.availableFeatures = []
            
            // Track cancellation if there was an active subscription
            if oldTier != nil {
                SubscriptionEvents.shared.trackSubscriptionCancelled(
                    tier: oldTier!,
                    reason: nil
                )
            }
        }
        
        saveSubscriptionState()
    }
    
    /// Restore purchases and subscription status
    func restorePurchases() async throws {
        // Will implement StoreKit integration here
    }
    
    // MARK: - Private Methods
    
    private func loadSubscriptionState() {
        if let storedTier = UserDefaults.standard.string(forKey: "subscription_tier"),
           let tier = SubscriptionTier(rawValue: storedTier) {
            updateSubscription(tier)
        }
    }
    
    private func saveSubscriptionState() {
        UserDefaults.standard.set(activeSubscription?.rawValue, forKey: "subscription_tier")
    }
    
    deinit {
        // No explicit cleanup needed for UserDefaults or simple properties
        // but provide deinit for consistency and future extensibility
    }
    
    /// Reset singleton state for testing
    func reset() {
        activeSubscription = nil
        availableFeatures.removeAll()
        loadSubscriptionState()
    }
}

/// Available subscription tiers
enum SubscriptionTier: String {
    case basic = "Basic"
    case premium = "Premium"
    case premium_plus = "Premium+"
    
    var displayName: String {
        switch self {
        case .basic: return "Basic"
        case .premium: return "Premium"
        case .premium_plus: return "Premium+"
        }
    }
    
    var description: String {
        switch self {
        case .basic:
            return "Core sleep tracking features"
        case .premium:
            return "Advanced analysis and extended history"
        case .premium_plus:
            return "All features including coaching and custom alarms"
        }
    }
    
    var monthlyPrice: Decimal {
        switch self {
        case .basic: return 0.00
        case .premium: return 4.99
        case .premium_plus: return 9.99
        }
    }
    
    var annualPrice: Decimal {
        monthlyPrice * 10 // 2 months free for annual
    }
}
