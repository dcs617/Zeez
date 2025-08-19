import SwiftUI
import Charts
import os.log

struct HeartRateView: View {
    let session: SleepSession?
    @State var selectedTimeRange: HeartRateTimeRange = .all
    @State var selectedDataPoint: HeartRateDataPoint?
    
    var body: some View {
        ScrollView {
            if let session = session,
               let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
               !heartRateData.isEmpty {
                VStack(spacing: 20) {
                    // Current Heart Rate Stats
                    currentStatsSection(data: heartRateData)
                    
                    // Heart Rate Chart
                    heartRateChartSection(data: heartRateData)
                    
                    // Heart Rate Variability
                    heartRateVariabilitySection(data: heartRateData)
                    
                    // Heart Rate Zones
                    heartRateZonesSection(data: heartRateData)
                    
                    // Sleep Stage Correlation
                    if let stages = session.sleepStages?.allObjects as? [SleepStage],
                       !stages.isEmpty {
                        sleepStageCorrelationSection(heartRateData: heartRateData, stages: stages)
                    }
                }
                .padding()
            } else {
                noDataView
            }
        }
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 44))
                .foregroundColor(.red.opacity(0.5))
            
            Text("No Heart Rate Data Available")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Make sure you wear your Apple Watch during sleep to record heart rate data.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No heart rate data available")
        .accessibilityHint("Wear your Apple Watch during sleep to record heart rate data")
        .accessibilityIdentifier("noHeartRateDataView")
    }
    
    private func currentStatsSection(data: [HeartRateData]) -> some View {
        //let basicStats = calculateBasicStats(data: data)
        let _ = calculateBasicStats(data: data)
        let detailedStats = calculateDetailedStats(data: data)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Summary")
                .font(.headline)
            
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 20) {
                HeartRateStatCard(
                    title: "Average",
                    value: detailedStats.average,
                    trend: detailedStats.averageTrend,
                    color: .blue
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Average heart rate: \(Int(detailedStats.average)) beats per minute")
                .accessibilityHint("Your average heart rate during sleep")
                .accessibilityIdentifier("averageHeartRateCard")
                
                HeartRateStatCard(
                    title: "Resting",
                    value: detailedStats.resting,
                    trend: detailedStats.restingTrend,
                    color: .green
                )
                
                HeartRateStatCard(
                    title: "Minimum",
                    value: detailedStats.minimum,
                    color: .indigo
                )
                
                HeartRateStatCard(
                    title: "Maximum",
                    value: detailedStats.maximum,
                    color: .red
                )
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    // Calculates basic stats for display
    private func calculateBasicStats(data: [HeartRateData]) -> HeartRateStats {
        let values = data.map { $0.value }
        return HeartRateStats(
            min: values.min() ?? 0,
            max: values.max() ?? 0,
            average: values.reduce(0, +) / Double(values.count)
        )
    }
    
    // Calculates detailed stats with trends
    private func calculateDetailedStats(data: [HeartRateData]) -> DetailedHeartRateStats {
        let values = data.map { $0.value }
        let average = values.reduce(0, +) / Double(values.count)
        
        // Calculate resting heart rate (average of lowest 20% of readings)
        let sortedValues = values.sorted()
        let restingCount = max(1, Int(Double(values.count) * 0.2))
        let restingValues = Array(sortedValues.prefix(restingCount))
        let resting = restingValues.reduce(0, +) / Double(restingValues.count)
        
        return DetailedHeartRateStats(
            average: Int(average),
            averageTrend: .neutral,
            resting: Int(resting),
            restingTrend: .down,
            minimum: Int(values.min() ?? 0),
            maximum: Int(values.max() ?? 0)
        )
    }
}
