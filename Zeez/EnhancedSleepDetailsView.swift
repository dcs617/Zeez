import SwiftUI
import CoreData

/// Comprehensive view displaying detailed sleep analysis for a session
struct EnhancedSleepDetailsView: View {
    @Environment(\.managedObjectContext) private var context
    
    let session: SleepSession
    
    /// Tracks if sleep stage analysis is in progress
    @State private var isAnalyzing = false
    
    /// Computed stages sorted by timestamp
    private var sortedStages: [SleepStage] {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage] else { 
            return []
        }
        return stages.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
    }
    
    private var sessionDuration: TimeInterval {
        guard let end = session.endTime,
              let start = session.startTime else { return 0 }
        return end.timeIntervalSince(start)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Session Overview Card
                sessionOverview
                
                // Sleep Stage Analysis Section
                Group {
                    if sortedStages.isEmpty {
                        analyzeButton
                    } else {
                        stageAnalysisSection
                    }
                }
                .padding(.horizontal)
                
                // Environmental Factors
                environmentalFactors
                    .padding(.horizontal)
                
                // Movement & Heart Rate
                biometricData
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Sleep Analysis")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var sessionOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.startTime?.formatted(date: .abbreviated, time: .shortened) ?? "")
                    .font(.headline)
                
                Text("→")
                    .foregroundColor(.secondary)
                
                Text(session.endTime?.formatted(date: .abbreviated, time: .shortened) ?? "")
                    .font(.headline)
            }
            
            HStack(spacing: 16) {
                Label {
                    Text("Sleep Quality")
                } icon: {
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(.purple)
                }
                
                Text("\(Int(session.qualityScore))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private var analyzeButton: some View {
        Button {
            Task {
                await analyzeSleepStages()
            }
        } label: {
            HStack {
                if isAnalyzing {
                    ProgressView()
                        .padding(.trailing, 4)
                }
                
                Text(isAnalyzing ? "Analyzing Sleep Stages..." : "Analyze Sleep Stages")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isAnalyzing)
    }
    
    private var stageAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Timeline visualization
            SleepStageVisualizer(stages: sortedStages, totalDuration: sessionDuration)
            
            Divider()
            
            // Detailed breakdown
            SleepStageMetrics(stages: sortedStages)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var environmentalFactors: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environmental Factors")
                .font(.headline)
            
            if let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
               !readings.isEmpty {
                // Display average readings
                VStack(spacing: 16) {
                    ForEach(aggregateEnvironmentalData(readings), id: \.label) { metric in
                        HStack {
                            Text(metric.label)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(metric.value)
                                .font(.subheadline)
                        }
                    }
                }
            } else {
                Text("No environmental data available")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var biometricData: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Biometric Data")
                .font(.headline)
            
            if let heartData = session.heartRateData?.allObjects as? [HeartRateData],
               let movementData = session.movementData?.allObjects as? [MovementData],
               !heartData.isEmpty || !movementData.isEmpty {
                
                VStack(spacing: 16) {
                    if !heartData.isEmpty {
                        HStack {
                            Text("Average Heart Rate")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(averageHeartRate(heartData))) BPM")
                                .font(.subheadline)
                        }
                    }
                    
                    if !movementData.isEmpty {
                        HStack {
                            Text("Movement Activity")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(movementLevel(movementData))
                                .font(.subheadline)
                        }
                    }
                }
            } else {
                Text("No biometric data available")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func analyzeSleepStages() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let analyzer = SleepStageAnalyzer(context: context)
        do {
            _ = try await analyzer.analyzeSleepStages(for: session)
        } catch {
            print("Error analyzing sleep stages: \(error)")
        }
    }
    
    private func aggregateEnvironmentalData(_ readings: [EnvironmentalReading]) -> [(label: String, value: String)] {
        let avgTemp = readings.compactMap { $0.temperature }.reduce(0, +) / Double(readings.count)
        let avgHumidity = readings.compactMap { $0.humidity }.reduce(0, +) / Double(readings.count)
        let avgNoise = readings.compactMap { $0.noiseLevel }.reduce(0, +) / Double(readings.count)
        
        return [
            ("Temperature", String(format: "%.1f°C", avgTemp)),
            ("Humidity", String(format: "%.0f%%", avgHumidity)),
            ("Noise Level", String(format: "%.0f dB", avgNoise))
        ]
    }
    
    private func averageHeartRate(_ data: [HeartRateData]) -> Double {
        let values = data.map { $0.value }
        return values.reduce(0, +) / Double(values.count)
    }
    
    private func movementLevel(_ data: [MovementData]) -> String {
        let avgMagnitude = data.map { $0.magnitude }.reduce(0, +) / Double(data.count)
        switch avgMagnitude {
        case 0...0.2: return "Minimal"
        case 0.2...0.5: return "Light"
        case 0.5...0.8: return "Moderate"
        default: return "High"
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let session = SleepSession(context: context)
    session.id = UUID()
    session.startTime = Date().addingTimeInterval(-28800) // 8 hours ago
    session.endTime = Date()
    session.qualityScore = 85
    
    return NavigationView {
        EnhancedSleepDetailsView(session: session)
            .environment(\.managedObjectContext, context)
    }
}
