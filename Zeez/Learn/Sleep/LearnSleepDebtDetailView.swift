import SwiftUI
import os.log

struct LearnSleepDebtAnalysisView: View {
    let debtHours: Double
    let recoveryDays: Int
    let recommendedHours: Double
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    debtSummary
                    
                    Divider()
                    
                    recoveryPlan
                    
                    Divider()
                    
                    preventionTips
                    
                    Divider()
                    
                    longTermEffects
                }
                .padding()
            }
            .navigationTitle("Sleep Debt Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                    .accessibilityLabel("Close sleep debt analysis")
                    .accessibilityHint("Return to previous screen")
                    .accessibilityIdentifier("closeSleepDebtAnalysisButton")
                }
            }
        }
    }
    
    private var debtSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Sleep Debt")
                .font(.headline)
                .accessibilityLabel("Sleep debt summary section")
                .accessibilityIdentifier("sleepDebtSummaryTitle")
            
            Text("You are currently \(String(format: "%.1f", debtHours)) hours behind your optimal sleep schedule. This represents a significant disruption to your natural sleep-wake cycle.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityLabel("You are currently \(String(format: "%.1f", debtHours)) hours behind your optimal sleep schedule")
                .accessibilityIdentifier("sleepDebtDescription")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sleepDebtSummarySection")
    }
    
    private var recoveryPlan: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Plan")
                .font(.headline)
                .accessibilityLabel("Recovery plan section")
                .accessibilityIdentifier("recoveryPlanTitle")
            
            Text("Recommended recovery approach:")
                .font(.subheadline)
                .accessibilityLabel("Recommended recovery approach")
            
            ForEach(getRecoverySteps(), id: \.self) { step in
                Label(step, systemImage: "arrow.right.circle")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .accessibilityLabel("Recovery step: \(step)")
                    .accessibilityIdentifier("recoveryStep_\(step.prefix(20).replacingOccurrences(of: " ", with: "_"))")
            }
            
            Text("Expected recovery period: \(recoveryDays) days")
                .font(.subheadline)
                .padding(.top, 8)
                .accessibilityLabel("Expected recovery period: \(recoveryDays) days")
                .accessibilityIdentifier("recoveryPeriod")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recoveryPlanSection")
    }
    
    private var preventionTips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prevention Tips")
                .font(.headline)
                .accessibilityLabel("Prevention tips section")
                .accessibilityIdentifier("preventionTipsTitle")
            
            ForEach(getPreventionTips(), id: \.self) { tip in
                Label(tip, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .accessibilityLabel("Prevention tip: \(tip)")
                    .accessibilityIdentifier("preventionTip_\(tip.prefix(20).replacingOccurrences(of: " ", with: "_"))")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("preventionTipsSection")
    }
    
    private var longTermEffects: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Long-term Effects")
                .font(.headline)
                .accessibilityLabel("Long-term effects section")
                .accessibilityIdentifier("longTermEffectsTitle")
            
            ForEach(getLongTermEffects(), id: \.self) { effect in
                Label(effect, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .accessibilityLabel("Long-term effect: \(effect)")
                    .accessibilityIdentifier("longTermEffect_\(effect.prefix(20).replacingOccurrences(of: " ", with: "_"))")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("longTermEffectsSection")
    }
    
    private func getRecoverySteps() -> [String] {
        [
            "Add \(String(format: "%.1f", min(1.5, debtHours/Double(recoveryDays)))) extra hours of sleep each night",
            "Maintain consistent bedtime at \(String(format: "%.1f", recommendedHours)) hours",
            "Avoid caffeine 6 hours before bed",
            "Create a relaxing bedtime routine",
            "Limit screen time before sleep"
        ]
    }
    
    private func getPreventionTips() -> [String] {
        [
            "Stick to a regular sleep schedule",
            "Create a sleep-friendly environment",
            "Exercise regularly, but not close to bedtime",
            "Manage stress through relaxation techniques",
            "Track your sleep patterns",
            "Avoid long naps during the day"
        ]
    }
    
    private func getLongTermEffects() -> [String] {
        [
            "Increased risk of cardiovascular disease",
            "Weakened immune system",
            "Impaired cognitive function",
            "Higher risk of depression and anxiety",
            "Weight gain and metabolic changes",
            "Reduced life expectancy"
        ]
    }
}

#Preview {
    LearnSleepDebtAnalysisView(debtHours: 12.5, recoveryDays: 8, recommendedHours: 8.0)
}
