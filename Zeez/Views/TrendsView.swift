import SwiftUI
import Charts
import CoreData
import os.log

struct TrendsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedRange: TrendTimeRange = .days
    @State private var monthlyData: MonthlyTrendData?
    @State private var isLoading = false
    @AppStorage("dev_showPremiumFeatures") private var showPremiumFeatures = false
    @State private var selectedSession: SleepSession?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TimeRangeSelectionView(selectedRange: $selectedRange)
                    .accessibilityLabel("Time range selection")
                    .accessibilityHint("Choose time range for sleep trends analysis")
                    .accessibilityIdentifier("timeRangeSelector")
                
                if isLoading {
                    loadingView
                        .accessibilityIdentifier("loadingView")
                } else {
                    trendContent
                        .accessibilityIdentifier("trendContent")
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Sleep Trends")
        .task {
            await loadData()
        }
        .onChange(of: selectedRange) { _, _ in
            Task {
                await loadData()
            }
        }
        .sheet(item: $selectedSession) { session in
            NavigationView {
                EnhancedSleepDetailsView(session: session)
            }
        }
        .accessibilityIdentifier("trendsView")
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .accessibilityLabel("Loading")
            Text("Analyzing sleep data...")
                .foregroundColor(.secondary)
                .accessibilityLabel("Analyzing sleep trends data")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading sleep trends analysis")
        .accessibilityIdentifier("loadingIndicator")
    }
    
    @ViewBuilder
    private var trendContent: some View {
        // Sleep goal shortfall is presented in its dedicated destination where source and
        // data coverage can be explained clearly.
        
        // Coverage first: every average below covers only the nights counted here.
        coverageCard
            .padding(.horizontal)

        // Experimental score trends. Nights without an estimate are absent, never zero.
        TrendMetricCard(
            title: "Experimental Zeez Estimate",
            subtitle: averageQualityScore == nil
                ? "No estimates in this period"
                : "Average of estimated nights in this period",
            value: averageQualityScore.map { "\(Int($0))" },
            valueColor: .blue
        ) {
            TrendChartComponents.QualityChart(
                data: fetchSleepQualities(),
                height: 150
            )
            .accessibilityLabel("Experimental Zeez estimate trend chart showing \(fetchSleepQualities().count) data points")
            .accessibilityValue(averageQualityScore.map { "Average experimental Zeez estimate \(Int($0)) out of 100" }
                                ?? "No experimental Zeez estimates in this period")
            .accessibilityIdentifier("qualityChart")
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(averageQualityScore.map { "Experimental Zeez estimate trends: average \(Int($0)) out of 100 for this period" }
                            ?? "Experimental Zeez estimate trends: no estimates in this period")
        .accessibilityIdentifier("qualityTrendCard")
        
        // Duration Trends
        TrendMetricCard(
            title: "Sleep Duration",
            subtitle: averageDurationFormatted == nil
                ? "No recorded sessions in this period"
                : "Average recorded session duration",
            value: averageDurationFormatted
        ) {
            TrendChartComponents.DurationChart(
                data: fetchSleepDurations(),
                height: 150
            )
            .accessibilityLabel("Recorded session duration trend chart showing \(fetchSleepDurations().count) data points")
            .accessibilityValue(averageDurationFormatted.map { "Average recorded session duration \($0)" }
                                ?? "No recorded sessions in this period")
            .accessibilityIdentifier("durationChart")
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(averageDurationFormatted.map { "Sleep duration trends: average \($0)" }
                            ?? "Sleep duration trends: no recorded sessions in this period")
        .accessibilityIdentifier("durationTrendCard")
        
        // Sleep Schedule Consistency
        TrendMetricCard(
            title: "Sleep Schedule",
            subtitle: "Sleep timing consistency"
        ) {
            ScheduleConsistencyChart(data: fetchScheduleData())
                .frame(height: 200)
                .accessibilityLabel("Sleep schedule consistency chart showing bedtime and wake time patterns")
                .accessibilityHint("Chart displaying consistency of sleep and wake times over the selected period")
                .accessibilityIdentifier("scheduleChart")
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sleep schedule consistency analysis")
        .accessibilityIdentifier("scheduleTrendCard")
        
        // Monthly Analysis
        if selectedRange == .month, let monthlyData = monthlyData {
            MonthlyChartSection(
                dataPoints: monthlyData.dataPoints,
                selectedDataPoint: .constant(monthlyData.dataPoints.last)
            )
            .padding(.horizontal)
            .accessibilityLabel("Monthly sleep analysis chart")
            .accessibilityIdentifier("monthlyChartSection")
            
            TrendInsightsSection(insights: monthlyData.insights)
            .padding(.horizontal)
            .accessibilityLabel("Monthly sleep insights")
            .accessibilityIdentifier("monthlyInsightsSection")
        }
        
        // Premium Features
        if !showPremiumFeatures {
            Group {
                TrendMetricCard(
                    title: "Heart Rate",
                    subtitle: "Nightly patterns and variability",
                    isPremium: true,
                    requiredFeature: .heartRateAnalysis
                ) {
                    EmptyView()
                }
                .accessibilityLabel("Heart rate analysis - Premium feature")
                .accessibilityHint("Upgrade to access nightly heart rate patterns and variability analysis")
                .accessibilityIdentifier("heartRatePremiumCard")
                
                TrendMetricCard(
                    title: "Sleep Environment",
                    subtitle: "Temperature, noise, and light",
                    isPremium: true,
                    requiredFeature: .environmentalAnalysis
                ) {
                    EmptyView()
                }
                .accessibilityLabel("Sleep environment analysis - Premium feature")
                .accessibilityHint("Upgrade to access temperature, noise, and light analysis")
                .accessibilityIdentifier("environmentPremiumCard")
                
                TrendMetricCard(
                    title: "Sleep Stages",
                    subtitle: "Deep, Light, and REM analysis",
                    isPremium: true,
                    requiredFeature: .detailedSleepStages
                ) {
                    EmptyView()
                }
                .accessibilityLabel("Sleep stages analysis - Premium feature")
                .accessibilityHint("Upgrade to access detailed deep, light, and REM sleep analysis")
                .accessibilityIdentifier("stagesPremiumCard")
            }
            .padding(.horizontal)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Premium features section")
            .accessibilityIdentifier("premiumFeaturesSection")
        }
    }
    
    private var coverageCard: some View {
        let coverage = nightCoverage
        return VStack(alignment: .leading, spacing: 4) {
            Text(coverage.summary)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(coverage.estimateSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(coverage.summary). \(coverage.estimateSummary).")
        .accessibilityHint("Averages below include only the recorded nights")
        .accessibilityIdentifier("nightCoverageCard")
    }

    private var nightCoverage: NightCoverage {
        let range = selectedRange.dateRange
        return NightCoverage.calculate(
            sessions: fetchSessions().compactMap { session in
                session.startTime.map { NightCoverage.Session(startTime: $0, hasEstimate: session.hasDisplayableScore) }
            },
            nightCount: NightCoverage.nightCount(from: range.start, to: range.end),
            now: range.end
        )
    }

    /// `nil` when the period has no estimate: an empty period is not a score of zero.
    private var averageQualityScore: Double? {
        let qualities = fetchSleepQualities()
        guard !qualities.isEmpty else { return nil }
        return qualities.reduce(0.0) { $0 + $1.value } / Double(qualities.count)
    }
    
    private var averageDurationFormatted: String? {
        let durations = fetchSleepDurations()
        guard !durations.isEmpty else { return nil }
        let avgHours = durations.reduce(0.0) { $0 + $1.value } / Double(durations.count)
        let hours = Int(avgHours)
        let minutes = Int((avgHours - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // Load monthly trends if needed
        if selectedRange == .month {
            do {
                let provider = MonthlyTrendsDataProvider(context: viewContext)
                monthlyData = try await provider.fetchMonthlyTrends()
            } catch {
                ErrorManager.shared.reportError(error)
                monthlyData = nil
            }
        } else {
            monthlyData = nil
        }
    }
    
    private func fetchSessions() -> [SleepSession] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        let range = selectedRange.dateRange
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime <= %@ AND isActive == NO",
            range.start as NSDate,
            range.end as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: true)
        ]
        return (try? viewContext.fetch(request)) ?? []
    }
    
    /// Recorded session intervals (`end - start`), not qualified asleep time —
    /// see the "Average recorded session duration" label on the card above.
    private func fetchSleepDurations() -> [(date: Date, value: Double)] {
        fetchSessions().compactMap { session -> (date: Date, value: Double)? in
            guard let start = session.startTime,
                  session.endTime != nil else { return nil }
            return (date: start, value: session.recordedInterval / 3600)
        }
    }
    
    private func fetchSleepQualities() -> [(date: Date, value: Double)] {
        fetchSessions().compactMap { session -> (date: Date, value: Double)? in
            guard let start = session.startTime,
                  session.hasDisplayableScore else { return nil }
            return (date: start, value: session.qualityScore)
        }
    }
    
    private func fetchScheduleData() -> [(date: Date, bedtime: Date, wakeTime: Date)] {
        fetchSessions().compactMap { session -> (date: Date, bedtime: Date, wakeTime: Date)? in
            guard let startTime = session.startTime,
                  let endTime = session.endTime else { return nil }
            return (date: startTime, bedtime: startTime, wakeTime: endTime)
        }
    }
}

#Preview {
    NavigationView {
        TrendsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
