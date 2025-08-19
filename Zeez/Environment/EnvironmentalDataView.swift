import SwiftUI
import CoreData
import os.log

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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Noise level chart showing readings from \(readings.first?.timestamp?.formatted() ?? "unknown") to \(readings.last?.timestamp?.formatted() ?? "unknown")")
                    .accessibilityHint("Shows noise levels during sleep session in decibels")
                    .accessibilityIdentifier("noiseLevelChart")
                    
                    MetricChartView(
                        title: "Light Level",
                        data: readings.map { ($0.timestamp ?? Date(), $0.lightLevel) },
                        color: .orange,
                        unit: "lux"
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Light level chart showing readings from \(readings.first?.timestamp?.formatted() ?? "unknown") to \(readings.last?.timestamp?.formatted() ?? "unknown")")
                    .accessibilityHint("Shows light levels during sleep session in lux")
                    .accessibilityIdentifier("lightLevelChart")
                    
                    if readings.contains(where: { $0.temperature > 0 }) {
                        MetricChartView(
                            title: "Temperature",
                            data: readings.map { ($0.timestamp ?? Date(), $0.temperature) },
                            color: .red,
                            unit: "°C"
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Temperature chart showing readings from \(readings.first?.timestamp?.formatted() ?? "unknown") to \(readings.last?.timestamp?.formatted() ?? "unknown")")
                        .accessibilityHint("Shows temperature during sleep session in degrees Celsius")
                        .accessibilityIdentifier("temperatureChart")
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
                .accessibilityHidden(true)
            
            Text("No Environmental Data")
                .font(.headline)
            
            Text("Environmental monitoring was not active during this session")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No Environmental Data. Environmental monitoring was not active during this session")
        .accessibilityIdentifier("environmentalDataEmptyState")
    }
    
    private var currentConditions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Conditions")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("currentConditionsHeader")
            
            LazyVGrid(columns: [.init(), .init()], spacing: 20) {
                MetricTile(
                    title: "Noise",
                    value: String(format: "%.1f dB", readings.last?.noiseLevel ?? 0),
                    icon: "ear",
                    color: .blue
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Noise level \(String(format: "%.1f", readings.last?.noiseLevel ?? 0)) decibels")
                .accessibilityIdentifier("noiseMetricTile")
                
                MetricTile(
                    title: "Light",
                    value: String(format: "%.1f lux", readings.last?.lightLevel ?? 0),
                    icon: "lightbulb",
                    color: .orange
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Light level \(String(format: "%.1f", readings.last?.lightLevel ?? 0)) lux")
                .accessibilityIdentifier("lightMetricTile")
                
                if let temp = readings.last?.temperature, temp > 0 {
                    MetricTile(
                        title: "Temperature",
                        value: String(format: "%.1f°C", temp),
                        icon: "thermometer",
                        color: .red
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Temperature \(String(format: "%.1f", temp)) degrees Celsius")
                    .accessibilityIdentifier("temperatureMetricTile")
                }
                
                if let humidity = readings.last?.humidity, humidity > 0 {
                    MetricTile(
                        title: "Humidity",
                        value: String(format: "%.1f%%", humidity),
                        icon: "humidity",
                        color: .cyan
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Humidity \(String(format: "%.1f", humidity)) percent")
                    .accessibilityIdentifier("humidityMetricTile")
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("currentConditionsSection")
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
                    .accessibilityHidden(true)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityIdentifier("metricTile_\(title.lowercased())")
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
                .accessibilityAddTraits(.isHeader)
            
            if !data.isEmpty {
                TrendChart(
                    data: data.map { ($0.0, $0.1) },
                    valueLabel: unit,
                    color: color
                )
                .frame(height: 150)
                .accessibilityLabel("\(title) chart with \(data.count) data points from \(String(format: "%.1f", data.min(by: { $0.1 < $1.1 })?.1 ?? 0)) to \(String(format: "%.1f", data.max(by: { $0.1 < $1.1 })?.1 ?? 0)) \(unit)")
                .accessibilityHint("Environmental measurement chart")
                .accessibilityIdentifier("trendChart_\(title.replacingOccurrences(of: " ", with: "").lowercased())")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("metricChartView_\(title.replacingOccurrences(of: " ", with: "").lowercased())")
    }
}
