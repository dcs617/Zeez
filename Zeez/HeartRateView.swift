import SwiftUI
import CoreData

/// View for displaying heart rate data during sleep
struct HeartRateView: View {
    @ObservedObject var session: SleepSession
    
    private var readings: [HeartRateData] {
        (session.heartRateData?.allObjects as? [HeartRateData] ?? [])
            .sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if readings.isEmpty {
                    emptyStateView
                } else {
                    currentHeartRate
                    heartRateChart
                    heartRateStats
                }
            }
            .padding()
        }
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 40))
                .foregroundColor(.red)
            
            Text("No Heart Rate Data")
                .font(.headline)
            
            Text("Heart rate monitoring was not active during this session")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var currentHeartRate: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Heart Rate")
                .font(.headline)
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(Int(readings.last?.value ?? 0))")
                    .font(.system(size: 48, weight: .bold))
                Text("BPM")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if readings.count > 1 {
                let trend = calculateTrend()
                HStack {
                    Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(abs(trend), specifier: "%.1f") BPM in last hour")
                }
                .foregroundColor(trend > 0 ? .orange : .green)
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var heartRateChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate Trend")
                .font(.headline)
            
            TrendChart(
                data: readings.map { ($0.timestamp ?? Date(), $0.value) },
                valueLabel: "BPM",
                color: .red
            )
            .frame(height: 200)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var heartRateStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
            let stats = calculateStats()
            LazyVGrid(columns: [.init(), .init()], spacing: 20) {
                StatTile(title: "Average", value: "\(Int(stats.average)) BPM")
                StatTile(title: "Maximum", value: "\(Int(stats.max)) BPM")
                StatTile(title: "Minimum", value: "\(Int(stats.min)) BPM")
                StatTile(title: "Resting", value: "\(Int(stats.resting)) BPM")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func calculateTrend() -> Double {
        guard readings.count > 1,
              let lastReading = readings.last,
              let lastTimestamp = lastReading.timestamp else { return 0 }
        
        let hourAgo = lastTimestamp.addingTimeInterval(-3600)
        let hourReadings = readings.filter { ($0.timestamp ?? Date()) >= hourAgo }
        
        guard let firstHourReading = hourReadings.first else { return 0 }
        return lastReading.value - firstHourReading.value
    }
    
    private func calculateStats() -> (average: Double, max: Double, min: Double, resting: Double) {
        let values = readings.map { $0.value }
        let sorted = values.sorted()
        
        let average = values.reduce(0, +) / Double(values.count)
        let maximum = sorted.last ?? 0
        let minimum = sorted.first ?? 0
        
        // Resting heart rate is approximated as the average of the lowest 10% of readings
        let restingCount = Swift.max(1, Int(Double(sorted.count) * 0.1))
        let resting = sorted.prefix(restingCount).reduce(0, +) / Double(restingCount)
        
        return (average: average, max: maximum, min: minimum, resting: resting)
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}
