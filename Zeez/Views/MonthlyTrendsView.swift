import SwiftUI
import CoreData
import os.log

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
                        .accessibilityLabel("Loading monthly trends data")
                        .accessibilityIdentifier("loadingProgress")
                } else if let data = trendData {
                    monthlyChart(data.dataPoints)
                        .accessibilityIdentifier("monthlyChart")
                    
                    NavigationLink(destination: LearnCircadianRhythmView()) {
                        CircadianPatternCard()
                    }
                    .accessibilityLabel("Learn about circadian sleep patterns")
                    .accessibilityHint("Navigate to educational content about sleep-wake patterns")
                    .accessibilityIdentifier("circadianPatternLink")
                    
                    insightsSection(data.insights)
                        .accessibilityIdentifier("insightsSection")
                    metricsBreakdown
                        .accessibilityIdentifier("metricsBreakdown")
                    
                    if selectedDataPoint?.sleepDebt ?? 0 > 0 {
                        NavigationLink(destination: LearnSleepDebtAnalysisView(debtHours: 14400, recoveryDays: 7, recommendedHours: 8.0)) {
                            SleepDebtEducationCard(
                                debt: selectedDataPoint?.sleepDebt ?? 0,
                                severity: getSeverity(selectedDataPoint?.sleepDebt ?? 0)
                            )
                        }
                        .accessibilityLabel("Learn about sleep debt analysis")
                        .accessibilityHint("Navigate to educational content about sleep debt recovery")
                        .accessibilityIdentifier("sleepDebtEducationLink")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Monthly Trends")
        .task {
            await loadTrendData()
        }
        .accessibilityIdentifier("monthlyTrendsView")
    }
    
    private func monthlyChart(_ dataPoints: [MonthlyDataPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Quality Trend")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("qualityTrendHeader")
                
                Spacer()
                
                NavigationLink(destination: LearnSleepStageComparisonView()) {
                    Label("Sleep Stages", systemImage: "chart.bar.doc.horizontal")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Learn about sleep stages")
                .accessibilityHint("Navigate to sleep stage comparison guide")
                .accessibilityIdentifier("sleepStagesLink")
            }
            
            TrendChart(
                data: dataPoints.map { point in
                    (date: point.month, value: point.metrics.averageQuality)
                },
                valueLabel: "Quality",
                color: .purple
            )
            .frame(height: 200)
            .accessibilityLabel("Monthly sleep quality trend chart showing \(dataPoints.count) months of data")
            .accessibilityHint("Chart displaying sleep quality trends over time")
            .accessibilityIdentifier("trendChart")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("monthlyChartContainer")
    }
    
    private func insightsSection(_ insights: [MonthlyInsight]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Insights")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("monthlyInsightsHeader")
            
            ForEach(Array(insights.enumerated()), id: \.element.description) { index, insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.icon)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    
                    Text(insight.description)
                        .font(.subheadline)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Insight \(index + 1): \(insight.description)")
                .accessibilityIdentifier("insight_\(index)")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insightsSectionContainer")
    }
    
    private var metricsBreakdown: some View {
        Group {
            if let point = selectedDataPoint {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(point.month, format: .dateTime.month(.wide))
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("selectedMonthHeader")
                        
                        Spacer()
                        
                        NavigationLink(destination: LearnCircadianRhythmView()) {
                            Label("Learn More", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .accessibilityLabel("Learn more about circadian rhythm")
                        .accessibilityHint("Navigate to educational content")
                        .accessibilityIdentifier("learnMoreLink")
                    }
                    
                    Grid(alignment: .leading) {
                        GridRow {
                            metricLabel("Average Duration")
                                .accessibilityIdentifier("durationLabel")
                            Text(formattedDuration(point.metrics.averageDuration))
                                .accessibilityLabel("Average duration \(formattedDuration(point.metrics.averageDuration))")
                                .accessibilityIdentifier("durationValue")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Average sleep duration \(formattedDuration(point.metrics.averageDuration))")
                        .accessibilityIdentifier("durationMetric")
                        
                        GridRow {
                            metricLabel("Sleep Quality")
                                .accessibilityIdentifier("qualityLabel")
                            Text(String(format: "%.1f", point.metrics.averageQuality))
                                .accessibilityLabel("Quality score \(String(format: "%.1f", point.metrics.averageQuality)) out of 100")
                                .accessibilityIdentifier("qualityValue")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Sleep quality \(String(format: "%.1f", point.metrics.averageQuality)) out of 100")
                        .accessibilityIdentifier("qualityMetric")
                        
                        GridRow {
                            metricLabel("Consistency")
                                .accessibilityIdentifier("consistencyLabel")
                            Text(String(format: "%.0f%%", point.consistency))
                                .accessibilityLabel("Consistency \(String(format: "%.0f", point.consistency)) percent")
                                .accessibilityIdentifier("consistencyValue")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Sleep consistency \(String(format: "%.0f", point.consistency)) percent")
                        .accessibilityIdentifier("consistencyMetric")
                        
                        GridRow {
                            metricLabel("Sleep Debt")
                                .accessibilityIdentifier("debtLabel")
                            HStack {
                                Text(formattedDuration(point.sleepDebt))
                                    .accessibilityLabel("Sleep debt \(formattedDuration(point.sleepDebt))")
                                if point.sleepDebt > 0 {
                                    NavigationLink(destination: LearnSleepDebtAnalysisView(debtHours: 14400, recoveryDays: 7, recommendedHours: 8.0)) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                    }
                                    .accessibilityLabel("Learn about sleep debt analysis")
                                    .accessibilityHint("Navigate to sleep debt education")
                                    .accessibilityIdentifier("sleepDebtInfoLink")
                                }
                            }
                            .accessibilityIdentifier("debtValue")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Sleep debt \(formattedDuration(point.sleepDebt))")
                        .accessibilityIdentifier("debtMetric")
                        
                        GridRow {
                            metricLabel("Sessions")
                                .accessibilityIdentifier("sessionsLabel")
                            Text("\(point.metrics.sessionCount)")
                                .accessibilityLabel("\(point.metrics.sessionCount) sessions")
                                .accessibilityIdentifier("sessionsValue")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(point.metrics.sessionCount) sleep sessions recorded")
                        .accessibilityIdentifier("sessionsMetric")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("metricsBreakdownContainer")
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
            ZeezLogger.error(ZeezLogger.ui, "Error loading trend data", error: error)
        }
    }
    
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    private func getSeverity(_ debt: TimeInterval) -> DebtSeverity {
        let debtHours = debt / 3600
        if debtHours <= 2 {
            return .minimal
        } else if debtHours <= 5 {
            return .moderate
        } else if debtHours <= 10 {
            return .significant
        } else {
            return .severe
        }
    }
}

struct CircadianPatternCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sleep-Wake Patterns", systemImage: "clock.fill")
                .font(.headline)
                .foregroundColor(.blue)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("sleepWakePatternsHeader")
            
            Text("Explore how your natural sleep rhythm affects your monthly sleep patterns")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("circadianDescription")
            
            HStack {
                Text("View Sleep Pattern Guide")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("View sleep pattern guide")
            .accessibilityIdentifier("viewGuidePrompt")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Circadian patterns card: Explore how your natural sleep rhythm affects your monthly sleep patterns")
        .accessibilityHint("Tap to learn about sleep-wake patterns")
        .accessibilityIdentifier("circadianPatternCard")
    }
}

#Preview {
    NavigationView {
        MonthlyTrendsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
