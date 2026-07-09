import SwiftUI
import CoreData
import os.log

struct TrendInsightsSection: View {
    let insights: [MonthlyInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Insights")
                .font(.headline)

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
        case .belowSelectedGoal:
            return .orange
        case .environmentalImprovementNeeded:
            return .blue
        }
    }
}

#Preview {
    VStack {
        TrendInsightsSection(
            insights: [
                .qualityImproving,
                .highConsistency,
                .environmentalImprovementNeeded(recommendations: [])
            ]
        )
        .padding()
    }
}
