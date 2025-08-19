import SwiftUI
import CoreData
import os.log

struct LearnEnvironmentalImpactView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedFactor: EnvironmentalFactor = .temperature
    @State private var showingDetail = false
    @State private var currentValue: Double = 0
    @State private var isLoading = true
    
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            factorSelector
            
            environmentalDisplay
                .onTapGesture {
                    showingDetail = true
                }
            
            historicalTrend
            
            recommendationCard
        }
        .padding()
        .onAppear {
            updateCurrentValue()
        }
        .onReceive(timer) { _ in
            updateCurrentValue()
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                EnvironmentalDetailView(factor: selectedFactor)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }
    
    private var factorSelector: some View {
        Picker("Environmental Factor", selection: $selectedFactor) {
            ForEach(EnvironmentalFactor.allCases, id: \.self) { factor in
                HStack {
                    Image(systemName: factor.icon)
                    Text(factor.rawValue)
                }.tag(factor)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedFactor) {
            updateCurrentValue()
        }
        .accessibilityLabel("Select environmental factor")
        .accessibilityHint("Choose which environmental factor to analyze")
        .accessibilityIdentifier("environmentalFactorPicker")
    }
    
    private var environmentalDisplay: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 20)
                .frame(width: 200, height: 200)
            
            let normalizedValue = getNormalizedValue()
            Circle()
                .trim(from: 0, to: normalizedValue)
                .stroke(
                    getColorForValue(currentValue),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
            
            VStack {
                Image(systemName: selectedFactor.icon)
                    .font(.title)
                    .foregroundColor(selectedFactor.color)
                    .accessibilityLabel("\(selectedFactor.rawValue) icon")
                if isLoading {
                    ProgressView()
                    .accessibilityLabel("Loading environmental data")
                } else {
                    Text(getFormattedValue(currentValue))
                        .font(.headline)
                    Text(selectedFactor.unit)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isLoading ? "Loading \(selectedFactor.rawValue) data" : "\(selectedFactor.rawValue): \(getFormattedValue(currentValue)) \(selectedFactor.unit)")
            .accessibilityHint("Tap to view detailed environmental information")
            .accessibilityIdentifier("environmentalDisplay")
        }
    }
    
    private var historicalTrend: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("24 Hour Trend")
                .font(.headline)
                .accessibilityLabel("24 hour trend section")
            
            let data = EnvironmentalDataManager.shared.getHistoricalData(
                for: selectedFactor,
                days: 1,
                context: viewContext
            )
            
            if data.isEmpty {
                Text("No historical data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No historical environmental data available")
            } else {
                // Here we could add a line chart showing the trend
                // For now, showing average
                let average = data.map { $0.1 }.reduce(0, +) / Double(data.count)
                HStack {
                    Text("Average:")
                        .foregroundColor(.secondary)
                    Text(getFormattedValue(average))
                        .bold()
                    Text(selectedFactor.unit)
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("24 hour average: \(getFormattedValue(average)) \(selectedFactor.unit)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("historicalTrendSection")
    }
    
    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .accessibilityLabel("Recommendation")
                Text("Recommendation")
                    .font(.headline)
            }
            
            Text(EnvironmentalDataManager.shared.getRecommendations(
                for: selectedFactor,
                value: currentValue
            ))
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recommendation: \(EnvironmentalDataManager.shared.getRecommendations(for: selectedFactor, value: currentValue))")
        .accessibilityIdentifier("recommendationCard")
    }
    
    private func updateCurrentValue() {
        isLoading = true
        let readings = EnvironmentalDataManager.shared.getLatestReadings(context: viewContext)
        
        switch selectedFactor {
        case .temperature:
            currentValue = readings[.temperature] ?? selectedFactor.optimalRange.min
        case .light:
            currentValue = readings[.light] ?? selectedFactor.optimalRange.min
        case .sound:
            currentValue = readings[.sound] ?? selectedFactor.optimalRange.min
        }
        
        isLoading = false
    }
    
    private func getNormalizedValue() -> Double {
        let range = selectedFactor.range
        return (currentValue - range.min) / (range.max - range.min)
    }
    
    private func getFormattedValue(_ value: Double) -> String {
        selectedFactor == .temperature ?
            String(format: "%.1f", value) :
            String(format: "%.0f", value)
    }
    
    private func getColorForValue(_ value: Double) -> Color {
        let score = EnvironmentalDataManager.shared.getOptimalityScore(
            for: selectedFactor,
            value: value
        )
        
        if score >= 0.8 {
            return .green
        } else if score >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    LearnEnvironmentalImpactView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .padding()
}
