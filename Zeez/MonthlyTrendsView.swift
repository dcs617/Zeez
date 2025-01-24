import SwiftUI
import CoreData

/// Displays monthly sleep trends and insights
struct MonthlyTrendsView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var trendData: MonthlyTrendData?
    @State private var isLoading = true
    @State private var selectedDataPoint: MonthlyDataPoint?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                        .padding()
                } else if let data = trendData {
                    monthlyChart(data.dataPoints)
                    
                    NavigationLink(destination: LearnCircadianRhythmView()) {
                        CircadianPatternCard()
                    }
                    
                    insightsSection(data.insights)
                    metricsBreakdown
                    
                    if selectedDataPoint?.sleepDebt ?? 0 > 0 {
                        NavigationLink(destination: LearnSleepDebtAnalysisView(debtHours: 14400, recoveryDays: 7, recommendedHours: 8.0)) {
                            SleepDebtEducationCard(
                                debt: selectedDataPoint?.sleepDebt ?? 0,
                                severity: getSeverity(selectedDataPoint?.sleepDebt ?? 0)
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Monthly Trends")
        .task {
            await loadTrendData()
        }
    }
    
    private func monthlyChart(_ dataPoints: [MonthlyDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Quality Trend")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: LearnSleepStageComparisonView()) {
                    Label("Sleep Stages", systemImage: "chart.bar.doc.horizontal")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            TrendChart(
                data: dataPoints.map { point in
                    (date: point.month, value: point.metrics.averageQuality)
                },
                valueLabel: "Quality",
                color: .purple
            )
            .frame(height: 200)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func insightsSection(_ insights: [MonthlyInsight]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Insights")
                .font(.headline)
            
            ForEach(insights, id: \.description) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.icon)
                        .foregroundColor(.blue)
                    
                    Text(insight.description)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var metricsBreakdown: some View {
        Group {
            if let point = selectedDataPoint {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(point.month, format: .dateTime.month(.wide))
                            .font(.headline)
                        
                        Spacer()
                        
                        NavigationLink(destination: LearnCircadianRhythmView()) {
                            Label("Learn More", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Grid(alignment: .leading) {
                        GridRow {
                            metricLabel("Average Duration")
                            Text(formattedDuration(point.metrics.averageDuration))
                        }
                        
                        GridRow {
                            metricLabel("Sleep Quality")
                            Text(String(format: "%.1f", point.metrics.averageQuality))
                        }
                        
                        GridRow {
                            metricLabel("Consistency")
                            Text(String(format: "%.0f%%", point.consistency))
                        }
                        
                        GridRow {
                            metricLabel("Sleep Debt")
                            HStack {
                                Text(formattedDuration(point.sleepDebt))
                                if point.sleepDebt > 0 {
                                    NavigationLink(destination: LearnSleepDebtAnalysisView(debtHours: 14400, recoveryDays: 7, recommendedHours: 8.0)) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        
                        GridRow {
                            metricLabel("Sessions")
                            Text("\(point.metrics.sessionCount)")
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    private func metricLabel(_ text: String) -> some View {
        Text(text)
            .foregroundColor(.secondary)
            .frame(width: 120, alignment: .leading)
    }
    
    private func loadTrendData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let provider = MonthlyTrendsDataProvider(context: context)
            trendData = try await provider.fetchMonthlyTrends()
            selectedDataPoint = trendData?.dataPoints.last
        } catch {
            print("Error loading trend data: \(error)")
        }
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    private func getSeverity(_ debt: TimeInterval) -> RecoveryPlan.Severity {
        switch debt {
        case ..<7200: return .mild
        case ..<14400: return .moderate
        default: return .severe
        }
    }
}

struct CircadianPatternCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sleep-Wake Patterns", systemImage: "clock.fill")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text("Explore how your natural sleep rhythm affects your monthly sleep patterns")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("View Sleep Pattern Guide")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        MonthlyTrendsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
