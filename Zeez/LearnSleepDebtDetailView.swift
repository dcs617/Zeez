import SwiftUI

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
                }
            }
        }
    }
    
    private var debtSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Sleep Debt")
                .font(.headline)
            
            Text("You are currently \(String(format: "%.1f", debtHours)) hours behind your optimal sleep schedule. This represents a significant disruption to your natural sleep-wake cycle.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var recoveryPlan: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Plan")
                .font(.headline)
            
            Text("Recommended recovery approach:")
                .font(.subheadline)
            
            ForEach(getRecoverySteps(), id: \.self) { step in
                Label(step, systemImage: "arrow.right.circle")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            
            Text("Expected recovery period: \(recoveryDays) days")
                .font(.subheadline)
                .padding(.top, 8)
        }
    }
    
    private var preventionTips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prevention Tips")
                .font(.headline)
            
            ForEach(getPreventionTips(), id: \.self) { tip in
                Label(tip, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
    }
    
    private var longTermEffects: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Long-term Effects")
                .font(.headline)
            
            ForEach(getLongTermEffects(), id: \.self) { effect in
                Label(effect, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
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