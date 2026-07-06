import SwiftUI
import CoreData
import os.log

struct TrendInsightsSection: View {
    let insights: [MonthlyInsight]
    let metrics: SleepDebtMetrics?
    @Binding var showingRecommendations: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Insights")
                    .font(.headline)
                
                Spacer()
                
                if metrics != nil {
                    Button(action: { showingRecommendations = true }) {
                        Label("Recommendations", systemImage: "lightbulb.fill")
                            .labelStyle(.iconOnly)
                            .foregroundColor(.yellow)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Circle())
                    }
                }
            }
            
            if insights.isEmpty {
                Text("Not enough data to generate insights")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(insights, id: \.description) { insight in
                    insightRow(insight)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(radius: 2)
        }
    }
    
    private func insightRow(_ insight: MonthlyInsight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .foregroundColor(insightColor(insight))
            
            Text(insight.description)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 4)
    }
    
    private func insightColor(_ insight: MonthlyInsight) -> Color {
        switch insight {
        case .qualityImproving, .highConsistency:
            return .green
        case .qualityDeclining, .lowConsistency:
            return .orange
        case .significantSleepDebt:
            return .red
        case .environmentalImprovementNeeded:
            return .blue
        }
    }
}

struct RecommendationsView: View {
    let metrics: SleepDebtMetrics
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Current Status") {
                    statusRow("Weekly Sleep Debt", 
                            formatDuration(metrics.weeklyDebt))
                    statusRow("Monthly Sleep Debt",
                            formatDuration(metrics.monthlyDebt))
                }
                
                Section("Recommendations") {
                    recommendationRow(metrics.recoveryPlan.recommendedAction)
                }
                
                Section("Recovery Timeline") {
                    Text(metrics.recoveryPlan.timeToRecover)
                    Text("Following this plan will help return your sleep schedule to normal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Sleep Recommendations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
    
    private func recommendationRow(_ recommendation: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(recommendation)
        }
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(abs(interval) / 3600)
        let minutes = Int((abs(interval).truncatingRemainder(dividingBy: 3600)) / 60)
        return String(format: "%dh %02dm", hours, minutes)
    }
}

#Preview {
    VStack {
        TrendInsightsSection(
            insights: [
                .qualityImproving,
                .highConsistency,
                .environmentalImprovementNeeded(recommendations: [])
            ],
            metrics: SleepDebtMetrics(
                weeklyDebt: 7200,
                monthlyDebt: 14400,
                debtTrend: .stable,
                recoveryPlan: RecoveryPlan(
                    recommendedAction: "Get an extra hour of sleep",
                    timeToRecover: "3 days",
                    severity: .moderate
                )
            ),
            showingRecommendations: .constant(false)
        )
        .padding()
    }
}
