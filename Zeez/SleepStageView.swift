import SwiftUI
import CoreData

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
                
                stageBreakdown
                
                if !sortedStages.isEmpty {
                    stageTimeline
                }
            }
            .padding()
        }
        .navigationTitle("Sleep Stages")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var stageDistributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage Distribution")
                .font(.headline)
            
            let distribution = calculateDistribution()
            
            VStack(spacing: 8) {
                ForEach(distribution.sorted(by: { $0.key > $1.key }), id: \.key) { stage, percentage in
                    StageProgressBar(
                        stage: stage,
                        percentage: percentage,
                        color: stageColor(for: stage)
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var stageBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage Analysis")
                .font(.headline)
            
            let stats = calculateStageStats()
            
            ForEach(stats.sorted(by: { $0.key > $1.key }), id: \.key) { stage, duration in
                HStack {
                    Circle()
                        .fill(stageColor(for: stage))
                        .frame(width: 12, height: 12)
                    
                    Text(stage.capitalized)
                    
                    Spacer()
                    
                    Text("\(duration / 60, specifier: "%.1f") hrs")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var stageTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)
            
            TimelineChart(stages: sortedStages)
                .frame(height: 100)
            
            timeAxis
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var timeAxis: some View {
        HStack {
            if let start = session.startTime {
                Text(start, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let end = session.endTime {
                    Text(end, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
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
        }
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
                    
                    ForEach(stages) { stage in
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
                        }
                    }
                }
            }
        }
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
