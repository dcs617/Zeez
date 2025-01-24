import SwiftUI
import CoreData

struct EnvironmentalDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let factor: EnvironmentalFactor
    @State private var timeRange = 7 // days
    @State private var historicalData: [(Date, Double)] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                factorInfo
                
                Divider()
                
                historicalAnalysis
                
                Divider()
                
                optimizationTips
            }
            .padding()
        }
        .navigationTitle(factor.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            loadHistoricalData()
        }
    }
    
    private var factorInfo: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: factor.icon)
                    .font(.title)
                    .foregroundColor(factor.color)
                
                VStack(alignment: .leading) {
                    Text("Optimal Range")
                        .font(.headline)
                    Text("\(formatValue(factor.optimalRange.min)) - \(formatValue(factor.optimalRange.max)) \(factor.unit)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(factorDescription)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var historicalAnalysis: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Historical Analysis")
                .font(.headline)
            
            Picker("Time Range", selection: $timeRange) {
                Text("Last Week").tag(7)
                Text("Last Month").tag(30)
                Text("Last 3 Months").tag(90)
            }
            .pickerStyle(.segmented)
            .onChange(of: timeRange) { oldValue, newValue in
                loadHistoricalData()
            }

            if historicalData.isEmpty {
                Text("No historical data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 12) {
                    statisticRow(title: "Average", value: average)
                    statisticRow(title: "Minimum", value: minimum)
                    statisticRow(title: "Maximum", value: maximum)
                    statisticRow(title: "Within Optimal Range", 
                               suffix: "%",
                               value: percentageInOptimalRange)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var optimizationTips: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optimization Tips")
                .font(.headline)
            
            ForEach(tips, id: \.self) { tip in
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    
                    Text(tip)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func statisticRow(title: String, suffix: String = "", value: Double) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(formatValue(value))\(suffix)")
                .bold()
        }
        .font(.subheadline)
    }
    
    private func formatValue(_ value: Double) -> String {
        factor == .temperature ? 
            String(format: "%.1f", value) :
            String(format: "%.0f", value)
    }
    
    private func loadHistoricalData() {
        historicalData = EnvironmentalDataManager.shared.getHistoricalData(
            for: factor,
            days: timeRange,
            context: viewContext
        )
    }
    
    private var average: Double {
        guard !historicalData.isEmpty else { return 0 }
        return historicalData.map { $0.1 }.reduce(0, +) / Double(historicalData.count)
    }
    
    private var minimum: Double {
        historicalData.map { $0.1 }.min() ?? 0
    }
    
    private var maximum: Double {
        historicalData.map { $0.1 }.max() ?? 0
    }
    
    private var percentageInOptimalRange: Double {
        guard !historicalData.isEmpty else { return 0 }
        let optimal = factor.optimalRange
        let inRange = historicalData.filter { 
            $0.1 >= optimal.min && $0.1 <= optimal.max 
        }.count
        return Double(inRange) / Double(historicalData.count) * 100
    }
    
    private var factorDescription: String {
        switch factor {
        case .temperature:
            return "Room temperature significantly affects sleep quality. Your body temperature naturally drops during sleep, and a cool environment supports this process."
        case .light:
            return "Light exposure influences your circadian rhythm. Darkness promotes melatonin production, while bright light can disrupt your sleep-wake cycle."
        case .sound:
            return "Noise levels can impact both falling asleep and sleep quality. Sudden changes in sound are more disruptive than consistent background noise."
        }
    }
    
    private var tips: [String] {
        switch factor {
        case .temperature:
            return [
                "Set your thermostat between 18-22°C (65-72°F) for optimal sleep",
                "Use breathable bedding materials to regulate temperature",
                "Consider using a fan for air circulation",
                "Take a warm bath before bed to trigger natural cooling"
            ]
        case .light:
            return [
                "Use blackout curtains or blinds to minimize external light",
                "Avoid blue light exposure 1-2 hours before bed",
                "Use dimmed, warm lighting in the evening",
                "Consider a sleep mask if needed"
            ]
        case .sound:
            return [
                "Use white noise to mask disruptive sounds",
                "Consider earplugs if environment is consistently noisy",
                "Soundproof windows can help reduce external noise",
                "Position bed away from noise sources"
            ]
        }
    }
}

#Preview {
    NavigationView {
        EnvironmentalDetailView(factor: .temperature)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
