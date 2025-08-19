import SwiftUI
import CoreData
import os.log

/// Detailed view of sleep stages for a session
/// Shows the progression of sleep stages over time with analysis
struct SleepStageView: View {
    @ObservedObject var session: SleepSession
    
    private var sortedStages: [SleepStage] {
        let stages = session.sleepStages?.allObjects as? [SleepStage] ?? []
        return stages.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                stageDistributionChart
                    .accessibilityIdentifier("stageDistributionChart")
                
                stageBreakdown
                    .accessibilityIdentifier("stageBreakdown")
                
                if !sortedStages.isEmpty {
                    stageTimeline
                        .accessibilityIdentifier("stageTimeline")
                }
            }
            .padding()
        }
        .navigationTitle("Sleep Stages")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("sleepStageView")
    }
    
    private var stageDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage Distribution")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("stageDistributionHeader")
            
            let distribution = calculateDistribution()
            
            VStack(spacing: 8) {
                ForEach(Array(distribution.sorted(by: { $0.key > $1.key }).enumerated()), id: \.element.key) { index, stageData in
                    StageProgressBar(
                        stage: stageData.key,
                        percentage: stageData.value,
                        color: stageColor(for: stageData.key)
                    )
                    .accessibilityLabel("\(stageData.key.capitalized) sleep stage \(Int(stageData.value)) percent")
                    .accessibilityIdentifier("stageProgressBar_\(index)")
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stageDistributionContainer")
    }
    
    private var stageBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage Analysis")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("stageAnalysisHeader")
            
            let stats = calculateStageStats()
            
            ForEach(Array(stats.sorted(by: { $0.key > $1.key }).enumerated()), id: \.element.key) { index, stageData in
                HStack {
                    Circle()
                        .fill(stageColor(for: stageData.key))
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                    
                    Text(stageData.key.capitalized)
                    
                    Spacer()
                    
                    Text("\(stageData.value / 60, specifier: "%.1f") hrs")
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stageData.key.capitalized) sleep stage duration \(stageData.value / 3600, specifier: "%.1f") hours")
                .accessibilityIdentifier("stageBreakdown_\(index)")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stageBreakdownContainer")
    }
    
    private var stageTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("timelineHeader")
            
            TimelineChart(stages: sortedStages)
                .frame(height: 100)
                .accessibilityLabel("Sleep stage timeline chart showing progression through \(sortedStages.count) sleep stages")
                .accessibilityHint("Visual timeline of your sleep stages throughout the night")
                .accessibilityIdentifier("timelineChart")
            
            timeAxis
                .accessibilityIdentifier("timeAxis")
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stageTimelineContainer")
    }
    
    private var timeAxis: some View {
        HStack {
            if let start = session.startTime {
                Text(start, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Sleep session started at \(start, style: .time)")
                    .accessibilityIdentifier("startTimeAxis")
                
                Spacer()
                
                if let end = session.endTime {
                    Text(end, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Sleep session ended at \(end, style: .time)")
                        .accessibilityIdentifier("endTimeAxis")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeAxisContainer")
    }
    
    private func calculateDistribution() -> [String: Double] {
        var distribution: [String: Double] = [:]
        let totalDuration = sortedStages.reduce(0.0) { $0 + $1.duration }
        
        for stage in sortedStages {
            if let type = stage.stageType {
                distribution[type, default: 0] += (stage.duration / totalDuration) * 100
            }
        }
        
        return distribution
    }
    
    private func calculateStageStats() -> [String: TimeInterval] {
        var stats: [String: TimeInterval] = [:]
        
        for stage in sortedStages {
            if let type = stage.stageType {
                stats[type, default: 0] += stage.duration
            }
        }
        
        return stats
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

/// Progress bar showing percentage of time in each sleep stage
private struct StageProgressBar: View {
    let stage: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(stage.capitalized)
                Spacer()
                Text("\(Int(percentage))%")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(stage.capitalized) sleep stage \(Int(percentage)) percent")
            .accessibilityIdentifier("stageLabel_\(stage.lowercased())")
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(UIColor.systemGray5))
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage / 100)
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
            .accessibilityElement(children: .ignore)
            .accessibilityValue("\(Int(percentage)) percent")
            .accessibilityIdentifier("progressBar_\(stage.lowercased())")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stageProgressBar_\(stage.lowercased())")
    }
}

/// Timeline chart showing sleep stage progression
private struct TimelineChart: View {
    let stages: [SleepStage]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if let firstStage = stages.first?.startTime,
                   let lastStage = stages.last?.endTime {
                    let totalDuration = lastStage.timeIntervalSince(firstStage)
                    
                    ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                        if let start = stage.startTime,
                           let end = stage.endTime,
                           let type = stage.stageType {
                            let x = geometry.size.width * 
                                   start.timeIntervalSince(firstStage) / totalDuration
                            let width = geometry.size.width * 
                                      end.timeIntervalSince(start) / totalDuration
                            
                            Rectangle()
                                .fill(stageColor(for: type))
                                .frame(width: max(1, width))
                                .position(x: x + width/2, y: geometry.size.height/2)
                                .accessibilityLabel("Sleep stage \(index + 1): \(type) sleep")
                                .accessibilityHint("Duration \(Int(stage.duration / 60)) minutes")
                                .accessibilityIdentifier("timelineStage_\(index)")
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timelineChartContainer")
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
