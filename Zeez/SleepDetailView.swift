import SwiftUI
import CoreData

struct SleepDetailView: View {
    @ObservedObject var session: SleepSession
    @Environment(\.managedObjectContext) private var viewContext
    
    private var qualityScore: SleepQualityScore? {
        session.qualityScores?.allObjects.first as? SleepQualityScore
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                sessionOverview
                
                if let score = qualityScore {
                    qualityScoreSection(score)
                }
                
                environmentalSection
                
                sleepStagesSection
                
                sleepMetricsSection
            }
            .padding()
        }
        .navigationTitle("Sleep Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var sessionOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session Overview")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: LearnCircadianRhythmView()) {
                    Label("Learn More", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if let start = session.startTime,
               let end = session.endTime {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Start").foregroundColor(.secondary)
                        Text(start, style: .time)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("End").foregroundColor(.secondary)
                        Text(end, style: .time)
                    }
                }
                
                Text("Duration: \(DateHelper.hoursBetween(start: start, end: end), specifier: "%.1f") hours")
                
                NavigationLink(destination: LearnSleepDebtView()) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("View Sleep Debt Analysis")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func qualityScoreSection(_ score: SleepQualityScore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Quality")
                .font(.headline)
            
            HStack {
                Text("\(Int(score.overallScore))")
                    .font(.system(size: 48, weight: .bold))
                Text("/ 100")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            componentScoreRow("Movement", score: score.movementScore)
            componentScoreRow("Environment", score: score.environmentalScore)
            componentScoreRow("Sleep Cycle", score: score.sleepCycleScore)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var environmentalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Room Conditions")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: LearnEnvironmentalImpactView()) {
                    Label("Learn More", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
               !readings.isEmpty {
                AverageEnvironmentalReadingView(readings: readings)
            } else {
                Text("No environmental data recorded")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var sleepStagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Stages")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: LearnSleepStageComparisonView()) {
                    Label("Compare Stages", systemImage: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if let stages = session.sleepStages?.allObjects as? [SleepStage],
               !stages.isEmpty {
                SleepStagePreviewChart(stages: stages)
                    .frame(height: 100)
                
                NavigationLink(destination: SleepStageView(session: session)) {
                    Text("View Detailed Analysis")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            } else {
                Text("No sleep stage data available")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var sleepMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Metrics")
                .font(.headline)
            
            HStack {
                metricCard(
                    title: "Avg Heart Rate",
                    value: averageHeartRate,
                    unit: "BPM"
                )
                
                metricCard(
                    title: "Movement",
                    value: movementCount,
                    unit: "events"
                )
            }
            
            NavigationLink(destination: LearnBrainActivityVisualizer()) {
                Label("View Brain Activity Analysis", systemImage: "brain.head.profile")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func componentScoreRow(_ title: String, score: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(Int(score))")
                .foregroundColor(.secondary)
        }
    }
    
    private func metricCard(title: String, value: Int, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.title2)
                    .bold()
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
    
    private var averageHeartRate: Int {
        guard let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
              !heartRateData.isEmpty else { return 0 }
        
        let total = heartRateData.reduce(0.0) { $0 + $1.value }
        return Int(total / Double(heartRateData.count))
    }
    
    private var movementCount: Int {
        guard let movementData = session.movementData?.allObjects as? [MovementData] else {
            return 0 }
        return movementData.filter { $0.activityLevel >= 3 }.count
    }
}

/// Preview chart for sleep stages
private struct SleepStagePreviewChart: View {
    let stages: [SleepStage]
    
    var body: some View {
        // Basic preview - will be enhanced in SleepStageView
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(stages) { stage in
                    Rectangle()
                        .fill(stageColor(for: stage.stageType ?? ""))
                        .frame(width: stageWidth(for: stage,
                                              totalWidth: geometry.size.width))
                }
            }
        }
    }
    
    private func stageWidth(for stage: SleepStage, totalWidth: CGFloat) -> CGFloat {
        let totalDuration = stages.reduce(0.0) { $0 + $1.duration }
        return (stage.duration / totalDuration) * totalWidth
    }
    
    private func stageColor(for type: String) -> Color {
        switch type.lowercased() {
        case "deep": return .blue
        case "light": return .green
        case "rem": return .purple
        default: return .gray
        }
    }
}
