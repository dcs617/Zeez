import SwiftUI
import CoreData

/// View for displaying movement and restlessness data during sleep
struct MovementDataView: View {
    @ObservedObject var session: SleepSession
    
    private var readings: [MovementData] {
        (session.movementData?.allObjects as? [MovementData] ?? [])
            .sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if readings.isEmpty {
                    emptyStateView
                } else {
                    activityOverview
                    movementChart
                    restlessPeriods
                }
            }
            .padding()
        }
        .navigationTitle("Movement")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.system(size: 40))
                .foregroundColor(.purple)
            
            Text("No Movement Data")
                .font(.headline)
            
            Text("Movement tracking was not active during this session")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var activityOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Overview")
                .font(.headline)
            
            let stats = calculateActivityStats()
            LazyVGrid(columns: [.init(), .init()], spacing: 20) {
                StatTile(
                    title: "Restless Periods",
                    value: "\(stats.restlessPeriods)",
                    icon: "waveform.path"
                )
                
                StatTile(
                    title: "Calm Periods",
                    value: "\(stats.calmPeriods)",
                    icon: "moon.zzz"
                )
                
                StatTile(
                    title: "Average Activity",
                    value: String(format: "%.1f", stats.averageActivity),
                    icon: "chart.bar"
                )
                
                StatTile(
                    title: "Peak Activity",
                    value: String(format: "%.1f", stats.peakActivity),
                    icon: "arrow.up.right"
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var movementChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Movement Intensity")
                .font(.headline)
            
            TrendChart(
                data: readings.map { ($0.timestamp ?? Date(), Double($0.activityLevel)) },
                valueLabel: "Level",
                color: .purple
            )
            .frame(height: 200)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var restlessPeriods: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Restless Periods")
                .font(.headline)
            
            let periods = identifyRestlessPeriods()
            if periods.isEmpty {
                Text("No significant restless periods detected")
                    .foregroundColor(.secondary)
            } else {
                ForEach(periods, id: \.start) { period in
                    RestlessPeriodRow(period: period)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func calculateActivityStats() -> (
        restlessPeriods: Int,
        calmPeriods: Int,
        averageActivity: Double,
        peakActivity: Double
    ) {
        let restlessThreshold: Int16 = 3
        let restless = readings.filter { $0.activityLevel >= restlessThreshold }.count
        let calm = readings.count - restless
        
        let avgActivity = Double(readings.reduce(0) { $0 + Int($1.activityLevel) }) /
                         Double(max(1, readings.count))
        let peakActivity = Double(readings.max(by: { $0.activityLevel < $1.activityLevel })?.activityLevel ?? 0)
        
        return (restlessPeriods: restless,
                calmPeriods: calm,
                averageActivity: avgActivity,
                peakActivity: peakActivity)
    }
    
    private func identifyRestlessPeriods() -> [(start: Date, end: Date, intensity: Double)] {
        var periods: [(start: Date, end: Date, intensity: Double)] = []
        var currentPeriodStart: Date?
        var currentIntensity: Double = 0
        let restlessThreshold: Int16 = 3
        
        for reading in readings {
            guard let timestamp = reading.timestamp else { continue }
            
            if reading.activityLevel >= restlessThreshold {
                if currentPeriodStart == nil {
                    currentPeriodStart = timestamp
                }
                currentIntensity = max(currentIntensity, Double(reading.activityLevel))
            } else if let start = currentPeriodStart {
                periods.append((start: start,
                              end: timestamp,
                              intensity: currentIntensity))
                currentPeriodStart = nil
                currentIntensity = 0
            }
        }
        
        return periods
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                Text(title)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            
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

private struct RestlessPeriodRow: View {
    let period: (start: Date, end: Date, intensity: Double)
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(FormatterUtils.timeFormatter.string(from: period.start))
                    .font(.headline)
                Text("Duration: \(FormatterUtils.formattedDuration(start: period.start, end: period.end))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("Level \(Int(period.intensity))")
                .font(.subheadline)
                .padding(6)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(6)
        }
        .padding(.vertical, 8)
    }
}
