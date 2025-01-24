import SwiftUI
import Charts
import CoreData

struct TrendsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedRange: TrendTimeRange = .days
    @State private var monthlyData: MonthlyTrendData?
    @State private var sleepMetrics: SleepDebtMetrics?
    @State private var isLoading = false
    @State private var showingRecommendations = false
    @AppStorage("dev_showPremiumFeatures") private var showPremiumFeatures = false
    @State private var selectedSession: SleepSession?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TimeRangeSelectionView(selectedRange: $selectedRange)
                
                if isLoading {
                    loadingView
                } else {
                    trendContent
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
        .sheet(isPresented: $showingRecommendations) {
            if let metrics = sleepMetrics {
                RecommendationsView(metrics: metrics)
            }
        }
        .sheet(item: $selectedSession) { session in
            NavigationView {
                EnhancedSleepDetailsView(session: session)
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Analyzing sleep data...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }
    
    @ViewBuilder
    private var trendContent: some View {
        if let metrics = sleepMetrics {
            SleepDebtSection(
                metrics: metrics,
                showingRecommendations: $showingRecommendations
            )
            .padding(.horizontal)
        }
        
        // Quality Trends
        TrendMetricCard(
            title: "Sleep Quality",
            subtitle: "Last \(selectedRange.rawValue)",
            value: "\(Int(averageQualityScore))%",
            valueColor: qualityScoreColor
        ) {
            TrendChartComponents.QualityChart(
                data: fetchSleepQualities(),
                height: 150
            )
        }
        .padding(.horizontal)
        
        // Duration Trends
        TrendMetricCard(
            title: "Sleep Duration",
            subtitle: "Average time asleep",
            value: averageDurationFormatted
        ) {
            TrendChartComponents.DurationChart(
                data: fetchSleepDurations(),
                height: 150
            )
        }
        .padding(.horizontal)
        
        // Sleep Schedule Consistency
        TrendMetricCard(
            title: "Sleep Schedule",
            subtitle: "Sleep timing consistency"
        ) {
            ScheduleConsistencyChart(data: fetchScheduleData())
                .frame(height: 200)
        }
        .padding(.horizontal)
        
        // Monthly Analysis
        if selectedRange == .month, let monthlyData = monthlyData {
            MonthlyChartSection(
                dataPoints: monthlyData.dataPoints,
                selectedDataPoint: .constant(monthlyData.dataPoints.last)
            )
            .padding(.horizontal)
            
            TrendInsightsSection(
                insights: monthlyData.insights,
                metrics: sleepMetrics,
                showingRecommendations: $showingRecommendations
            )
            .padding(.horizontal)
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
                
                TrendMetricCard(
                    title: "Sleep Environment",
                    subtitle: "Temperature, noise, and light",
                    isPremium: true,
                    requiredFeature: .environmentalAnalysis
                ) {
                    EmptyView()
                }
                
                TrendMetricCard(
                    title: "Sleep Stages",
                    subtitle: "Deep, Light, and REM analysis",
                    isPremium: true,
                    requiredFeature: .detailedSleepStages
                ) {
                    EmptyView()
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var averageQualityScore: Double {
        let qualities = fetchSleepQualities()
        guard !qualities.isEmpty else { return 0 }
        return qualities.reduce(0.0) { $0 + $1.value } / Double(qualities.count)
    }
    
    private var qualityScoreColor: Color {
        switch averageQualityScore {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .yellow
        default: return .red
        }
    }
    
    private var averageDurationFormatted: String {
        let durations = fetchSleepDurations()
        guard !durations.isEmpty else { return "0h 0m" }
        let avgHours = durations.reduce(0.0) { $0 + $1.value } / Double(durations.count)
        let hours = Int(avgHours)
        let minutes = Int((avgHours - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load sleep debt metrics
            sleepMetrics = try await SleepDebtCalculator.shared.calculateSleepDebtMetrics()
            
            // Load monthly trends if needed
            if selectedRange == .month {
                let provider = MonthlyTrendsDataProvider(context: viewContext)
                monthlyData = try await provider.fetchMonthlyTrends()
            } else {
                monthlyData = nil
            }
        } catch {
            ErrorManager.shared.reportError(error)
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
    
    private func fetchSleepDurations() -> [(date: Date, value: Double)] {
        fetchSessions().compactMap { session -> (date: Date, value: Double)? in
            guard let start = session.startTime,
                  let end = session.endTime else { return nil }
            return (date: start, value: end.timeIntervalSince(start) / 3600)
        }
    }
    
    private func fetchSleepQualities() -> [(date: Date, value: Double)] {
        fetchSessions().compactMap { session -> (date: Date, value: Double)? in
            guard let start = session.startTime else { return nil }
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