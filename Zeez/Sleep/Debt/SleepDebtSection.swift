import SwiftUI
import CoreData
import os.log

struct SleepDebtSection: View {
    let metrics: SleepDebtMetrics
    @Binding var showingRecommendations: Bool
    @State private var showingSleepDebtDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sleep Debt Overview")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingSleepDebtDetail = true }) {
                    Label("Learn More", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Weekly")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatDuration(metrics.weeklyDebt))
                        .font(.title2)
                        .foregroundColor(debtColor(metrics.weeklyDebt))
                }
                
                Divider()
                
                VStack(alignment: .leading) {
                    Text("Monthly")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatDuration(metrics.monthlyDebt))
                        .font(.title2)
                        .foregroundColor(debtColor(metrics.monthlyDebt))
                }
                
                Spacer()
                
                Button(action: { showingRecommendations = true }) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
            }
            
            if let trend = trendDescription(metrics.debtTrend) {
                HStack {
                    Image(systemName: trendIcon(metrics.debtTrend))
                    Text(trend)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            if !metrics.recoveryPlan.recommendedAction.isEmpty {
                recoveryPlanView(metrics.recoveryPlan)
            }
            
            NavigationLink(destination: LearnSleepDebtAnalysisView(debtHours: 14400, recoveryDays: 7, recommendedHours: 8.0)) {
                SleepDebtEducationCard(
                    debt: metrics.weeklyDebt,
                    severity: metrics.recoveryPlan.severity
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .sheet(isPresented: $showingSleepDebtDetail) { 
            NavigationView {
                LearnSleepDebtAnalysisView(debtHours: 14400, recoveryDays: 7, recommendedHours: 8.0)
            }
        }
    }
    
    private func recoveryPlanView(_ plan: RecoveryPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recovery Plan")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Label(plan.recommendedAction,
                      systemImage: "bed.double.fill")
                
                Label("Time to recover: \(plan.timeToRecover)",
                      systemImage: "clock.fill")
            }
            .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(recoveryPlanColor(plan.severity))
                .opacity(0.1)
        )
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(abs(interval) / 3600)
        let minutes = Int((abs(interval).truncatingRemainder(dividingBy: 3600)) / 60)
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    private func debtColor(_ debt: TimeInterval) -> Color {
        switch debt {
        case ..<0: return .green
        case 0..<7200: return .yellow
        default: return .red
        }
    }
    
    private func trendDescription(_ trend: DebtTrend) -> String? {
        switch trend {
        case .improving: return "Sleep debt is decreasing"
        case .stable: return "Sleep debt is stable"
        case .worsening: return "Sleep debt is increasing"
        }
    }
    
    private func trendIcon(_ trend: DebtTrend) -> String {
        switch trend {
        case .improving: return "arrow.down.right"
        case .stable: return "equal"
        case .worsening: return "arrow.up.right"
        }
    }
    
    private func recoveryPlanColor(_ severity: DebtSeverity) -> Color {
        return severity.color
    }
}
