import SwiftUI
import CoreData

struct StatsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTimeRange: SleepStatsRange = .days
    @State private var showingWidgetPicker = false
    @State private var sleepMetrics: SleepDebtMetrics?
    @State private var isLoadingMetrics = false
    @State private var recommendedBedtime: Date?
    @State private var showingRecommendations = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    timeRangeSelector
                    
                    if isLoadingMetrics {
                        loadingView
                    } else if let metrics = sleepMetrics {
                        sleepDebtOverview(metrics)
                        sleepQualityChart
                        sleepScheduleChart
                        recoveryPlanSection(metrics)
                    }
                    
                    addWidgetButton
                }
                .padding(.vertical)
            }
            .navigationTitle("Sleep Stats")
            .sheet(isPresented: $showingRecommendations) {
                if let metrics = sleepMetrics {
                    RecommendationsView(metrics: metrics)
                }
            }
            .task {
                await loadSleepMetrics()
            }
        }
    }
    
    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SleepStatsRange.allCases) { range in
                    TimeRangeButton(
                        title: range.description,
                        isSelected: selectedTimeRange == range,
                        action: {
                            selectedTimeRange = range
                            Task {
                                await loadSleepMetrics()
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
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
    
    private func sleepDebtOverview(_ metrics: SleepDebtMetrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Debt Overview")
                .font(.headline)
            
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
                        .background(Color(UIColor.secondarySystemBackground))
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
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private var sleepQualityChart: some View {
        ChartSection(title: "Sleep Quality", showMore: true) {
            SleepQualityChart(data: fetchSleepQualityData())
                .frame(height: 200)
        }
    }
    
    private var sleepScheduleChart: some View {
        ChartSection(title: "Sleep Schedule", showMore: true) {
            SleepScheduleChart(data: fetchSleepScheduleData())
                .frame(height: 200)
        }
    }
    
    private func recoveryPlanSection(_ metrics: SleepDebtMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Plan")
                .font(.headline)
                .padding(.horizontal)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Label(metrics.recoveryPlan.recommendedAction,
                          systemImage: "bed.double.fill")
                    
                    Label("Time to recover: \(metrics.recoveryPlan.timeToRecover)",
                          systemImage: "clock.fill")
                }
                .font(.subheadline)
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(recoveryPlanColor(metrics.recoveryPlan.severity))
                    .opacity(0.1)
            )
            .padding(.horizontal)
        }
    }
    
    private var addWidgetButton: some View {
        Button(action: { showingWidgetPicker = true }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Widget")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private func loadSleepMetrics() async {
        isLoadingMetrics = true
        defer { isLoadingMetrics = false }
        
        do {
            sleepMetrics = try await SleepDebtCalculator.shared.calculateSleepDebtMetrics()
        } catch {
            ErrorManager.shared.reportError(error)
        }
    }
    
    private func fetchSleepQualityData() -> [(Date, Double)] {
        // Add your fetch logic here
        return []
    }
    
    private func fetchSleepScheduleData() -> [(hour: Int, sleepProbability: Double)] {
        // Add your fetch logic here to return hourly sleep probability data
        return []  // Temporary return until implementation
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
    
    private func recoveryPlanColor(_ severity: RecoveryPlan.Severity) -> Color {
        switch severity {
        case .mild: return .green
        case .moderate: return .yellow
        case .severe: return .red
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
            .navigationBarItems(trailing: Button("Done") { dismiss() })
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

struct StatsView_Previews: PreviewProvider {
    static var previews: some View {
        StatsView()
    }
}
