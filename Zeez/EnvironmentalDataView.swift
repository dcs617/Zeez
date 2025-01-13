import SwiftUI
import CoreData

/// View for displaying environmental conditions during sleep
struct EnvironmentalDataView: View {
    @ObservedObject var session: SleepSession
    
    private var readings: [EnvironmentalReading] {
        (session.environmentalReadings?.allObjects as? [EnvironmentalReading] ?? [])
            .sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if readings.isEmpty {
                    emptyStateView
                } else {
                    currentConditions
                    
                    MetricChartView(
                        title: "Noise Level",
                        data: readings.map { ($0.timestamp ?? Date(), $0.noiseLevel) },
                        color: .blue,
                        unit: "dB"
                    )
                    
                    MetricChartView(
                        title: "Light Level",
                        data: readings.map { ($0.timestamp ?? Date(), $0.lightLevel) },
                        color: .orange,
                        unit: "lux"
                    )
                    
                    if readings.contains(where: { $0.temperature > 0 }) {
                        MetricChartView(
                            title: "Temperature",
                            data: readings.map { ($0.timestamp ?? Date(), $0.temperature) },
                            color: .red,
                            unit: "°C"
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Room Conditions")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "thermometer")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No Environmental Data")
                .font(.headline)
            
            Text("Environmental monitoring was not active during this session")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var currentConditions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Conditions")
                .font(.headline)
            
            LazyVGrid(columns: [.init(), .init()], spacing: 20) {
                MetricTile(
                    title: "Noise",
                    value: String(format: "%.1f dB", readings.last?.noiseLevel ?? 0),
                    icon: "ear",
                    color: .blue
                )
                
                MetricTile(
                    title: "Light",
                    value: String(format: "%.1f lux", readings.last?.lightLevel ?? 0),
                    icon: "lightbulb",
                    color: .orange
                )
                
                if let temp = readings.last?.temperature, temp > 0 {
                    MetricTile(
                        title: "Temperature",
                        value: String(format: "%.1f°C", temp),
                        icon: "thermometer",
                        color: .red
                    )
                }
                
                if let humidity = readings.last?.humidity, humidity > 0 {
                    MetricTile(
                        title: "Humidity",
                        value: String(format: "%.1f%%", humidity),
                        icon: "humidity",
                        color: .cyan
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
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

private struct MetricChartView: View {
    let title: String
    let data: [(Date, Double)]
    let color: Color
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            if !data.isEmpty {
                TrendChart(
                    data: data.map { ($0.0, $0.1) },
                    valueLabel: unit,
                    color: color
                )
                .frame(height: 150)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}