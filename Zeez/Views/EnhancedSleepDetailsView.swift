import SwiftUI
import CoreData
import os.log

/// Comprehensive view displaying detailed sleep analysis for a session
struct EnhancedSleepDetailsView: View {
    let session: SleepSession
    
    /// Computed stages sorted by timestamp
    private var sortedStages: [SleepStage] {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage] else { 
            return []
        }
        return stages.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Session Overview Card
                sessionOverview
                    .accessibilityIdentifier("sessionOverview")
                
                // Sleep Stage Analysis Section
                Group {
                    if sortedStages.isEmpty {
                        noStagesView
                            .accessibilityIdentifier("noStagesView")
                    } else {
                        stageAnalysisSection
                            .accessibilityIdentifier("stageAnalysisSection")
                    }
                }
                .padding(.horizontal)
                
                // Environmental Factors
                environmentalFactors
                    .padding(.horizontal)
                    .accessibilityIdentifier("environmentalFactors")
                
                // Movement & Heart Rate
                biometricData
                    .padding(.horizontal)
                    .accessibilityIdentifier("biometricData")
            }
            .padding(.vertical)
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("enhancedSleepDetailsView")
    }
    
    private var sessionOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.startTime?.formatted(date: .abbreviated, time: .shortened) ?? "")
                    .font(.headline)
                
                Text("→")
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                Text(session.endTime?.formatted(date: .abbreviated, time: .shortened) ?? "")
                    .font(.headline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Sleep session from \(session.startTime?.formatted(date: .abbreviated, time: .shortened) ?? "unknown time") to \(session.endTime?.formatted(date: .abbreviated, time: .shortened) ?? "unknown time")")
            .accessibilityIdentifier("sessionTimeRange")
            
            if session.hasDisplayableScore {
                HStack(spacing: 16) {
                    Label {
                        Text("Experimental Zeez Estimate")
                    } icon: {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(.purple)
                            .accessibilityHidden(true)
                    }

                    Text("\(Int(session.qualityScore))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Experimental Zeez estimated sleep score \(Int(session.qualityScore)) out of 100")
                .accessibilityIdentifier("sleepQualityScore")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sessionOverviewContainer")
    }
    
    private var noStagesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Sleep Stage Analysis")
                .font(.headline)
            Text("Stage analysis requires sensor data from a wearable device or an Apple Health import that includes stage information.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sleep stage analysis not available. Stage analysis requires sensor data from a wearable device or Apple Health import.")
    }
    
    private var stageAnalysisSection: some View {
        SleepStagesChart(session: session)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Sleep stage timeline and summary")
            .accessibilityHint("Shows Apple Health-reported or experimental Zeez-estimated sleep stages for this session")
            .accessibilityIdentifier("stageAnalysisSectionContainer")
    }
    
    private var environmentalFactors: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Environmental Factors")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("environmentalFactorsHeader")
            
            if let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
               !readings.isEmpty {
                // Display average readings
                VStack(spacing: 16) {
                    ForEach(Array(aggregateEnvironmentalData(readings).enumerated()), id: \.element.label) { index, metric in
                        HStack {
                            Text(metric.label)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(metric.value)
                                .font(.subheadline)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(metric.label) \(metric.value)")
                        .accessibilityIdentifier("environmentalMetric_\(index)")
                    }
                }
            } else {
                Text("No environmental data available")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No environmental data was recorded for this sleep session")
                    .accessibilityIdentifier("noEnvironmentalData")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("environmentalFactorsContainer")
    }
    
    private var biometricData: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Biometric Data")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("biometricDataHeader")
            
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
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Average heart rate \(Int(averageHeartRate(heartData))) beats per minute")
                        .accessibilityIdentifier("averageHeartRate")
                    }
                    
                    if !movementData.isEmpty {
                        HStack {
                            Text("Movement Activity")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(movementLevel(movementData))
                                .font(.subheadline)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Movement activity level \(movementLevel(movementData))")
                        .accessibilityIdentifier("movementActivity")
                    }
                }
            } else {
                Text("No biometric data available")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No biometric data was recorded for this sleep session")
                    .accessibilityIdentifier("noBiometricData")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("biometricDataContainer")
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
