import SwiftUI
import CoreData
import os.log

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
                    .accessibilityIdentifier("sessionOverview")
                
                if let score = qualityScore {
                    qualityScoreSection(score)
                        .accessibilityIdentifier("qualityScoreSection")
                }
                
                environmentalSection
                    .accessibilityIdentifier("environmentalSection")
                
                sleepStagesSection
                    .accessibilityIdentifier("sleepStagesSection")
                
                sleepMetricsSection
                    .accessibilityIdentifier("sleepMetricsSection")
            }
            .padding()
        }
        .navigationTitle("Sleep Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("sleepDetailView")
    }
    
    private var sessionOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session Overview")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("sessionOverviewHeader")
                
                Spacer()
                
                NavigationLink(destination: LearnCircadianRhythmView()) {
                    Label("Learn More", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Learn about circadian rhythm")
                .accessibilityHint("Navigate to educational content about sleep cycles")
                .accessibilityIdentifier("learnCircadianLink")
            }
            
            if let start = session.startTime,
               let end = session.endTime {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Start").foregroundColor(.secondary)
                        Text(start, style: .time)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Sleep session started at \(start, style: .time)")
                    .accessibilityIdentifier("sessionStartTime")
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("End").foregroundColor(.secondary)
                        Text(end, style: .time)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Sleep session ended at \(end, style: .time)")
                    .accessibilityIdentifier("sessionEndTime")
                }
                
                Text("Duration: \(DateHelper.hoursBetween(start: start, end: end), specifier: "%.1f") hours")
                    .accessibilityLabel("Total sleep duration \(DateHelper.hoursBetween(start: start, end: end), specifier: "%.1f") hours")
                    .accessibilityIdentifier("sessionDuration")
                
                NavigationLink(destination: LearnSleepDebtView()) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)
                        Text("View Sleep Debt Analysis")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .accessibilityLabel("View sleep debt analysis")
                .accessibilityHint("Navigate to learn about sleep debt and recovery")
                .accessibilityIdentifier("sleepDebtLink")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sessionOverviewContainer")
    }
    
    private func qualityScoreSection(_ score: SleepQualityScore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Quality")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("sleepQualityHeader")
            
            HStack {
                Text("\(Int(score.overallScore))")
                    .font(.system(size: 48, weight: .bold))
                Text("/ 100")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Overall sleep quality score \(Int(score.overallScore)) out of 100")
            .accessibilityIdentifier("overallQualityScore")
            
            componentScoreRow("Movement", score: score.movementScore)
                .accessibilityIdentifier("movementScore")
            componentScoreRow("Environment", score: score.environmentalScore)
                .accessibilityIdentifier("environmentScore")
            componentScoreRow("Sleep Cycle", score: score.sleepCycleScore)
                .accessibilityIdentifier("sleepCycleScore")
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("qualityScoreContainer")
    }
    
    private var environmentalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Room Conditions")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("roomConditionsHeader")
                
                Spacer()
                
                NavigationLink(destination: LearnEnvironmentalImpactView()) {
                    Label("Learn More", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Learn about environmental impact on sleep")
                .accessibilityHint("Navigate to educational content about sleep environment")
                .accessibilityIdentifier("learnEnvironmentLink")
            }
            
            if let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
               !readings.isEmpty {
                AverageEnvironmentalReadingView(readings: readings)
                    .accessibilityIdentifier("environmentalReadings")
            } else {
                Text("No environmental data recorded")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No environmental data was recorded for this sleep session")
                    .accessibilityIdentifier("noEnvironmentalData")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("environmentalContainer")
    }
    
    private var sleepStagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Stages")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("sleepStagesHeader")
                
                Spacer()
                
                NavigationLink(destination: LearnSleepStageComparisonView()) {
                    Label("Compare Stages", systemImage: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Compare sleep stages")
                .accessibilityHint("Navigate to learn about different sleep stages")
                .accessibilityIdentifier("compareStagesLink")
            }
            
            if let stages = session.sleepStages?.allObjects as? [SleepStage],
               !stages.isEmpty {
                SleepStagePreviewChart(stages: stages)
                    .frame(height: 100)
                    .accessibilityLabel("Sleep stages chart showing \(stages.count) different sleep periods")
                    .accessibilityHint("Visual representation of sleep stages throughout the night")
                    .accessibilityIdentifier("sleepStagesChart")
                
                NavigationLink(destination: SleepStageView(session: session)) {
                    Text("View Detailed Analysis")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("View detailed sleep stage analysis")
                .accessibilityHint("Navigate to comprehensive sleep stage breakdown")
                .accessibilityIdentifier("detailedAnalysisLink")
            } else {
                Text("No sleep stage data available")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No sleep stage data was recorded for this session")
                    .accessibilityIdentifier("noStageData")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleepStagesContainer")
    }
    
    private var sleepMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Metrics")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("sleepMetricsHeader")
            
            HStack {
                metricCard(
                    title: "Avg Heart Rate",
                    value: averageHeartRate,
                    unit: "BPM"
                )
                .accessibilityIdentifier("heartRateMetric")
                
                metricCard(
                    title: "Movement",
                    value: movementCount,
                    unit: "events"
                )
                .accessibilityIdentifier("movementMetric")
            }
            
            NavigationLink(destination: LearnBrainActivityVisualizer()) {
                Label("View Brain Activity Analysis", systemImage: "brain.head.profile")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .accessibilityLabel("View brain activity analysis")
            .accessibilityHint("Navigate to learn about brain activity during sleep")
            .accessibilityIdentifier("brainActivityLink")
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleepMetricsContainer")
    }
    
    private func componentScoreRow(_ title: String, score: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(Int(score))")
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) score \(Int(score)) out of 100")
        .accessibilityIdentifier("componentScore_\(title.lowercased().replacingOccurrences(of: " ", with: ""))")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value) \(unit)")
        .accessibilityIdentifier("metricCard_\(title.lowercased().replacingOccurrences(of: " ", with: ""))")
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
                ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                    Rectangle()
                        .fill(stageColor(for: stage.stageType ?? ""))
                        .frame(width: stageWidth(for: stage,
                                              totalWidth: geometry.size.width))
                        .accessibilityLabel("Sleep stage \(index + 1): \(stage.stageType ?? "unknown") sleep")
                        .accessibilityHint("Duration \(Int(stage.duration / 60)) minutes")
                        .accessibilityIdentifier("stageSegment_\(index)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleepStagePreviewChart")
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
