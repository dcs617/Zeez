import SwiftUI

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var premiumManager = PremiumManager.shared
    @State private var selectedTier: SubscriptionTier?
    @State private var isAnnual = true
    @State private var isProcessing = false
    
    let requiredFeature: PremiumFeature?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                
                if let feature = requiredFeature {
                    requiredFeatureCard(feature)
                }
                
                subscriptionTiers
                
                featureComparison
                
                subscribeButton
                
                restoreButton
            }
            .padding()
        }
        .navigationTitle("Upgrade Zeez")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .overlay {
            if isProcessing {
                ProgressView()
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text("Upgrade to Premium")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Get the most out of your sleep tracking")
                .foregroundColor(.secondary)
        }
    }
    
    private func requiredFeatureCard(_ feature: PremiumFeature) -> some View {
        VStack(spacing: 12) {
            Image(systemName: feature.iconName)
                .font(.title)
                .foregroundColor(.purple)
            
            Text(feature.rawValue)
                .font(.headline)
            
            Text(feature.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var subscriptionTiers: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Your Plan")
                .font(.headline)
            
            HStack {
                ForEach([SubscriptionTier.premium, .premium_plus], id: \.self) { tier in
                    tierCard(tier)
                }
            }
            
            Toggle("Annual Plan (Save 20%)", isOn: $isAnnual)
                .tint(.purple)
        }
    }
    
    private func tierCard(_ tier: SubscriptionTier) -> some View {
        let isSelected = selectedTier == tier
        
        return VStack(spacing: 12) {
            Text(tier.displayName)
                .font(.headline)
            
            Text(tier.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(priceString(for: tier))
                .font(.title3)
                .fontWeight(.bold)
            
            Text(isAnnual ? "per year" : "per month")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture {
            selectedTier = tier
        }
    }
    
    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Features")
                .font(.headline)
            
            ForEach(PremiumFeature.allCases, id: \.self) { feature in
                HStack {
                    Image(systemName: feature.iconName)
                        .foregroundColor(.purple)
                        .frame(width: 24)
                    
                    Text(feature.rawValue)
                    
                    Spacer()
                    
                    ForEach([SubscriptionTier.premium, .premium_plus], id: \.self) { tier in
                        Image(systemName: premiumManager.features(for: tier).contains(feature) ? 
                            "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(premiumManager.features(for: tier).contains(feature) ?
                                .green : .secondary)
                            .frame(width: 80)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var subscribeButton: some View {
        Button {
            Task {
                await subscribe()
            }
        } label: {
            if let tier = selectedTier {
                Text("Subscribe for \(priceString(for: tier))")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
            } else {
                Text("Select a Plan")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple.opacity(0.5))
                    .cornerRadius(12)
            }
        }
        .disabled(selectedTier == nil)
    }
    
    private var restoreButton: some View {
        Button {
            Task {
                await restorePurchases()
            }
        } label: {
            Text("Restore Purchases")
                .foregroundColor(.purple)
        }
    }
    
    private func priceString(for tier: SubscriptionTier) -> String {
        let price = isAnnual ? tier.annualPrice : tier.monthlyPrice
        return "$\(price)"
    }
    
    private func subscribe() async {
        guard let tier = selectedTier else { return }
        isProcessing = true
        defer { isProcessing = false }
        
        // Track subscription attempt
        SubscriptionEvents.shared.trackSubscriptionStarted(
            tier: tier,
            isAnnual: isAnnual,
            source: .settings  // or whatever source is appropriate
        )
        
        // TODO: Implement StoreKit purchase
        // For now, simulate subscription
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        premiumManager.updateSubscription(tier)
        dismiss()
    }
    
    private func restorePurchases() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            try await premiumManager.restorePurchases()
            if premiumManager.activeSubscription != nil {
                dismiss()
            }
        } catch {
            print("Error restoring purchases: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        SubscriptionView(requiredFeature: .detailedSleepStages)
    }
}
