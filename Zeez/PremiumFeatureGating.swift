import SwiftUI

/// View modifier to gate premium features
struct PremiumGate: ViewModifier {
    let feature: PremiumFeature
    @StateObject private var premiumManager = PremiumManager.shared
    @State private var showingUpgradeSheet = false
    
    func body(content: Content) -> some View {
        Group {
            if premiumManager.hasAccess(to: feature) {
                content
            } else {
                Button {
                    showingUpgradeSheet = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: feature.iconName)
                            .font(.largeTitle)
                            .foregroundColor(.purple)
                        
                        Text(feature.rawValue)
                            .font(.headline)
                        
                        Text("Premium Feature")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                }
            }
        }
        .sheet(isPresented: $showingUpgradeSheet) {
            NavigationView {
                SubscriptionView(requiredFeature: feature)
            }
        }
    }
}

/// Convenience extension for premium gating
extension View {
    func requiresPremium(_ feature: PremiumFeature) -> some View {
        modifier(PremiumGate(feature: feature))
    }
}

/// Helper to handle premium feature access
struct PremiumFeatureAccess {
    static func checkAccess(_ feature: PremiumFeature) -> Bool {
        return PremiumManager.shared.hasAccess(to: feature)
    }
    
    @ViewBuilder
    static func wrapContent<Content: View>(
        _ feature: PremiumFeature,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if PremiumManager.shared.hasAccess(to: feature) {
            content()
        } else {
            EmptyView()
        }
    }
}

/// Example Usage:
///
/// ```swift
/// struct DetailedAnalysisView: View {
///     var body: some View {
///         VStack {
///             // This section requires premium
///             DetailedStagesView()
///                 .requiresPremium(.detailedSleepStages)
///             
///             // This section is free
///             BasicStatsView()
///         }
///     }
/// }
/// ```