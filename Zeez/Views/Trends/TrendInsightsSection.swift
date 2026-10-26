import SwiftUI
import CoreData
import os.log

struct TrendInsightsSection: View {
    let insights: [MonthlyInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Observations")
                .font(.headline)

            if insights.isEmpty {
                Text("Not enough recorded nights for observations yet")
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
                .fill(Color(.secondarySystemBackground))
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
        case .qualityImproving:
            return .green
        case .qualityDeclining:
            return .orange
        case .startTimeSpread:
            return .blue
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
                .startTimeSpread(SleepStartSpread(standardDeviation: 25 * 60, nights: 12)),
                .environmentalImprovementNeeded(recommendations: [])
            ]
        )
        .padding()
    }
}
