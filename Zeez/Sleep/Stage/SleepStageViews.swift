import SwiftUI
import Charts
import os.log

struct SleepStageBreakdown: View {
    let stages: [SleepStage]
    
    private var stageData: [(String, TimeInterval)] {
        let grouped = Dictionary(grouping: stages, by: { $0.stageType ?? "Unknown" })
        return grouped.map { (type, stages) in
            (type, stages.reduce(0) { $0 + $1.duration })
        }.sorted { $0.0 < $1.0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stages")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("sleepStagesHeader")
            
            Chart(stageData, id: \.0) { stage in
                SectorMark(
                    angle: .value("Duration", stage.1),
                    innerRadius: .ratio(0.618),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Stage", stage.0))
            }
            .frame(height: 200)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Sleep stages pie chart showing \(generateStagesAccessibilityText())")
            .accessibilityHint("Visual breakdown of time spent in each sleep stage")
            .accessibilityIdentifier("sleepStagesChart")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(stageData.enumerated()), id: \.element.0) { index, stage in
                    StageMetricRow(
                        stage: stage.0,
                        duration: stage.1,
                        total: stageData.reduce(0) { $0 + $1.1 }
                    )
                    .accessibilityIdentifier("stageMetric_\(index)")
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleepStageBreakdown")
    }
    
    private func generateStagesAccessibilityText() -> String {
        let total = stageData.reduce(0) { $0 + $1.1 }
        return stageData.map { stage in
            let percentage = total > 0 ? Int((stage.1 / total) * 100) : 0
            return "\(percentage)% \(stage.0.lowercased()) sleep"
        }.joined(separator: ", ")
    }
}

private struct StageMetricRow: View {
    let stage: String
    let duration: TimeInterval
    let total: TimeInterval
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return (duration / total) * 100
    }
    
    var formattedDuration: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stage)
                .font(.subheadline)
                .bold()
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("stageTitle_\(stage.lowercased())")
            
            HStack {
                Text("\(Int(percentage))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(Int(percentage)) percent, duration \(formattedDuration)")
            .accessibilityIdentifier("stageStats_\(stage.lowercased())")
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(stageColor)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            .accessibilityElement(children: .ignore)
            .accessibilityValue("\(Int(percentage)) percent")
            .accessibilityIdentifier("stageProgressBar_\(stage.lowercased())")
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(stage) sleep stage: \(Int(percentage)) percent, \(formattedDuration)")
        .accessibilityIdentifier("stageMetricRow_\(stage.lowercased())")
    }
    
    private var stageColor: Color {
        switch stage {
        case "DEEP": return .blue
        case "LIGHT": return .green
        case "REM": return .purple
        case "AWAKE": return .orange
        default: return .gray
        }
    }
}
