import SwiftUI
import Charts
import os.log

struct EnvironmentalFactors: View {
    let readings: [EnvironmentalReading]
    @State private var selectedTab = 0
    
    var body: some View {
        environmentalContent
    }
    
    private var environmentalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environmental Factors")
                .font(.headline)
            
            environmentalPicker
            environmentalChart
            environmentalStats
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private var environmentalPicker: some View {
        HStack {
            Button(action: { selectedTab = 0 }) {
                Text("Temp")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedTab == 0 ? Color.blue : Color.clear)
                    .foregroundColor(selectedTab == 0 ? .white : .primary)
                    .cornerRadius(8)
            }
            
            Button(action: { selectedTab = 1 }) {
                Text("Humidity")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedTab == 1 ? Color.blue : Color.clear)
                    .foregroundColor(selectedTab == 1 ? .white : .primary)
                    .cornerRadius(8)
            }
            
            Button(action: { selectedTab = 2 }) {
                Text("Noise")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedTab == 2 ? Color.blue : Color.clear)
                    .foregroundColor(selectedTab == 2 ? .white : .primary)
                    .cornerRadius(8)
            }
            
            Button(action: { selectedTab = 3 }) {
                Text("Light")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(selectedTab == 3 ? Color.blue : Color.clear)
                    .foregroundColor(selectedTab == 3 ? .white : .primary)
                    .cornerRadius(8)
            }
        }
        .padding(4)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
    }
    
    private var environmentalChart: some View {
        Chart {
            ForEach(sortedReadings, id: \.timestamp) { reading in
                LineMark(
                    x: .value("Time", reading.timestamp ?? Date()),
                    y: .value("Value", value(for: reading))
                )
                .foregroundStyle(Color.blue.gradient)
            }
            
            RuleMark(y: .value("Min", optimalRange.0))
                .foregroundStyle(.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            
            RuleMark(y: .value("Max", optimalRange.1))
                .foregroundStyle(.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
        .frame(height: 200)
    }
    
    private var environmentalStats: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Average")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(Int(average))\(currentUnit)")
                    .font(.title3)
                    .bold()
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("Optimal Range")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(Int(optimalRange.0))-\(Int(optimalRange.1))\(currentUnit)")
                    .font(.title3)
                    .bold()
            }
        }
        .padding(.top)
    }
    
    private var currentUnit: String {
        switch selectedTab {
        case 0: return "°C"
        case 1: return "%"
        case 2: return "dB"
        case 3: return "lux"
        default: return ""
        }
    }
    
    private var sortedReadings: [EnvironmentalReading] {
        readings.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
    }
    
    private func value(for reading: EnvironmentalReading) -> Double {
        switch selectedTab {
        case 0: return reading.temperature
        case 1: return reading.humidity
        case 2: return reading.noiseLevel
        case 3: return reading.lightLevel
        default: return 0
        }
    }
    
    private var average: Double {
        let values = readings.map(value)
        return values.reduce(0, +) / Double(max(values.count, 1))
    }
    
    private var optimalRange: (Double, Double) {
        switch selectedTab {
        case 0: return (18, 21)  // Temperature °C
        case 1: return (30, 50)  // Humidity %
        case 2: return (0, 30)   // Noise dB
        case 3: return (0, 5)    // Light lux
        default: return (0, 0)
        }
    }
}
