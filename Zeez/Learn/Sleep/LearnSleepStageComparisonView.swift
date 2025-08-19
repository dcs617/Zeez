import SwiftUI
import os.log

struct LearnSleepStageComparisonView: View {
    @State private var selectedMetric: ComparisonMetric = .brainActivity
    @State private var showingDetail = false
    @State private var animateValues = false
    
    enum ComparisonMetric: String, CaseIterable {
        case brainActivity = "Brain Activity"
        case bodyMovement = "Body Movement"
        case memoryProcessing = "Memory Processing"
        case energyRestoration = "Energy Restoration"
        
        var remValue: Double {
            switch self {
            case .brainActivity: return 0.9
            case .bodyMovement: return 0.1
            case .memoryProcessing: return 0.9
            case .energyRestoration: return 0.3
            }
        }
        
        var deepValue: Double {
            switch self {
            case .brainActivity: return 0.2
            case .bodyMovement: return 0.05
            case .memoryProcessing: return 0.4
            case .energyRestoration: return 0.95
            }
        }
        
        var description: String {
            switch self {
            case .brainActivity:
                return "REM shows high brain activity similar to wakefulness, while deep sleep shows slow-wave patterns"
            case .bodyMovement:
                return "REM features muscle paralysis except for eyes, deep sleep has minimal movement"
            case .memoryProcessing:
                return "REM consolidates emotional and procedural memories, deep sleep processes declarative memories"
            case .energyRestoration:
                return "Deep sleep focuses on physical restoration, REM maintains brain function"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            metricPicker
            
            comparisonChart
                .onTapGesture {
                    showingDetail = true
                }
            
            metricDescription
            
            keyDifferences
        }
        .padding()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animateValues = true
            }
        }
        .sheet(isPresented: $showingDetail) {
            StageComparisonDetailView(metric: selectedMetric)
        }
    }
    
    private var metricPicker: some View {
        Picker("Comparison Metric", selection: $selectedMetric) {
            ForEach(ComparisonMetric.allCases, id: \.self) { metric in
                Text(metric.rawValue).tag(metric)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Select comparison metric")
        .accessibilityHint("Choose which aspect of sleep stages to compare")
        .accessibilityIdentifier("comparisonMetricPicker")
    }
    
    private var comparisonChart: some View {
        VStack(spacing: 20) {
            // REM Bar
            VStack(alignment: .leading, spacing: 8) {
                Label("REM Sleep", systemImage: "moonphase.full.moon")
                    .font(.headline)
                    .accessibilityLabel("REM Sleep")
                
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple)
                        .frame(width: geometry.size.width * (animateValues ? selectedMetric.remValue : 0))
                        .overlay(
                            Text("\(Int(selectedMetric.remValue * 100))%")
                                .foregroundColor(.white)
                                .padding(.leading, 8),
                            alignment: .leading
                        )
                }
                .frame(height: 30)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("REM Sleep \(selectedMetric.rawValue): \(Int(selectedMetric.remValue * 100)) percent")
                .accessibilityIdentifier("remSleepBar")
            }
            
            // Deep Sleep Bar
            VStack(alignment: .leading, spacing: 8) {
                Label("Deep Sleep", systemImage: "moon.fill")
                    .font(.headline)
                    .accessibilityLabel("Deep Sleep")
                
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.indigo)
                        .frame(width: geometry.size.width * (animateValues ? selectedMetric.deepValue : 0))
                        .overlay(
                            Text("\(Int(selectedMetric.deepValue * 100))%")
                                .foregroundColor(.white)
                                .padding(.leading, 8),
                            alignment: .leading
                        )
                }
                .frame(height: 30)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Deep Sleep \(selectedMetric.rawValue): \(Int(selectedMetric.deepValue * 100)) percent")
                .accessibilityIdentifier("deepSleepBar")
            }
        }
        .frame(height: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sleep stage comparison chart for \(selectedMetric.rawValue). REM Sleep: \(Int(selectedMetric.remValue * 100)) percent, Deep Sleep: \(Int(selectedMetric.deepValue * 100)) percent")
        .accessibilityHint("Tap to view detailed comparison information")
        .accessibilityIdentifier("comparisonChart")
    }
    
    private var metricDescription: some View {
        VStack(spacing: 8) {
            Text(selectedMetric.rawValue)
                .font(.headline)
            
            Text(selectedMetric.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(selectedMetric.rawValue). \(selectedMetric.description)")
        .accessibilityIdentifier("metricDescription")
    }
    
    private var keyDifferences: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Differences")
                .font(.headline)
                .accessibilityLabel("Key differences section")
            
            ForEach(getDifferences(), id: \.self) { difference in
                Label(difference, systemImage: "circle.fill")
                    .font(.subheadline)
                    .accessibilityLabel("Difference: \(difference)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("keyDifferencesSection")
    }
    
    private func getDifferences() -> [String] {
        switch selectedMetric {
        case .brainActivity:
            return [
                "REM: Active dreaming state",
                "Deep: Slow-wave delta activity"
            ]
        case .bodyMovement:
            return [
                "REM: Muscle atonia present",
                "Deep: Occasional position changes"
            ]
        case .memoryProcessing:
            return [
                "REM: Emotional memory focus",
                "Deep: Fact-based memory focus"
            ]
        case .energyRestoration:
            return [
                "REM: Mental restoration",
                "Deep: Physical recovery"
            ]
        }
    }
}

#Preview {
    LearnSleepStageComparisonView()
}
