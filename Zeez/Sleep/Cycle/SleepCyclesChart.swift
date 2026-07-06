import SwiftUI
import Charts
import CoreData
import os.log

struct SleepStagesChart: View {
    let session: SleepSession

    private var metrics: DerivedSleepMetrics {
        session.derivedSleepMetrics
    }

    private var hasHeartRateData: Bool {
        (session.heartRateData?.count ?? 0) > 0
    }

    internal var stageColors: [SleepStageType: Color] = [
        .awake: Color(red: 0.95, green: 0.8, blue: 0.5),      // Soft Yellow
        .lightSleep: Color(red: 0.7, green: 0.85, blue: 0.9), // Light Blue
        .asleepUnspecified: Color(red: 0.55, green: 0.75, blue: 0.8),
        .deepSleep: Color(red: 0.5, green: 0.6, blue: 0.8),   // Deep Blue
        .rem: Color(red: 0.8, green: 0.7, blue: 0.9)          // Soft Purple
    ]
    
    internal var heartRateMetrics: HeartRateStats {
        let heartRateData = (session.heartRateData?.allObjects as? [HeartRateData]) ?? []
        let values = heartRateData.map { $0.value }
        return HeartRateStats(
            min: values.min() ?? 0,
            max: values.max() ?? 0,
            average: values.reduce(0, +) / Double(max(values.count, 1))
        )
    }
    
    internal var stageData: [(stage: SleepStageType, startTime: Date, duration: TimeInterval)] {
        let stages = (session.sleepStages?.allObjects as? [SleepStage]) ?? []
        return stages.compactMap { stage in
            guard let startTime = stage.startTime,
                  let type = SleepStageType.normalize(stage.stageType) else { return nil }
            
            return (type, startTime, stage.duration)
        }.sorted { $0.startTime < $1.startTime }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Stages")
                .font(.headline)

            Text(session.stageSourceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ZStack(alignment: .topLeading) {
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(stageData, id: \.startTime) { dataPoint in
                            BarMark(
                                x: .value("Time", dataPoint.startTime),
                                y: .value("Stage", stageValueForType(dataPoint.stage)),
                                width: .fixed(10)
                            )
                            .foregroundStyle(stageColors[dataPoint.stage] ?? .gray)
                        }
                        
                        // Event markers
                        if let startTime = session.startTime {
                            RuleMark(x: .value("Bed Time", startTime))
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                        
                        if let endTime = session.endTime {
                            RuleMark(x: .value("Wake Time", endTime))
                                .foregroundStyle(.gray.opacity(0.5))
                        }
                    }
                    .chartYScale(domain: 0...4)
                    .chartYAxis {
                        AxisMarks(values: [0, 1, 2, 3, 4]) { value in
                            AxisValueLabel {
                                Text(stageLabelForValue(value.index))
                            }
                        }
                    }
                    .frame(height: 300)
                } else {
                    Text("Charts require iOS 16 or later")
                        .foregroundColor(.gray)
                }
                
                // Heart Rate Stats Box
                if hasHeartRateData {
                    HeartRateStatsBox(stats: heartRateMetrics)
                        .padding(8)
                        .background(Color(UIColor.systemBackground).opacity(0.9))
                        .cornerRadius(8)
                        .padding(8)
                }
            }
            
            // Legend
            HStack(spacing: 16) {
                ForEach(SleepStageType.allCases, id: \.self) { stage in
                    SleepStageLegendItem(
                        color: stageColors[stage] ?? .gray,
                        label: stage.displayName(reportedByAppleHealth: session.hasSourceReportedStages)
                    )
                }
            }
            .padding(.top, 8)
            
            // Session and stage duration information
            if let recordedInterval = metrics.recordedSessionInterval.value {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration Summary")
                        .font(.subheadline)
                        .bold()
                    
                    HStack(spacing: 20) {
                        StatInfoItem(
                            label: "Recorded Interval",
                            value: formatDuration(recordedInterval)
                        )
                        
                        StatInfoItem(
                            label: session.hasSourceReportedStages ? "Reported Sleep" : "Experimental Zeez Sleep Estimate",
                            value: formattedAsleepDuration
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func stageValueForType(_ type: SleepStageType) -> Int {
        switch type {
        case .awake: return 4
        case .rem: return 3
        case .asleepUnspecified: return 2
        case .lightSleep: return 1
        case .deepSleep: return 0
        }
    }
    
    private func stageLabelForValue(_ value: Int) -> String {
        switch value {
        case 0: return "Deep"
        case 1: return session.hasSourceReportedStages ? "Core" : "Light"
        case 2: return "Asleep Unspecified"
        case 3: return "REM"
        case 4: return "Awake"
        default: return ""
        }
    }
    
    private var formattedAsleepDuration: String {
        if session.hasSourceReportedStages {
            guard let duration = metrics.qualifiedAsleepDuration.value else { return "Unavailable" }
            return formatDuration(duration)
        }
        guard let composition = metrics.asleepStageComposition.value else { return "Unavailable" }
        return formatDuration(composition.values.reduce(0, +))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}

struct HeartRateStatsBox: View {
    let stats: HeartRateStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Heart Rate")
                .font(.caption)
                .bold()
            
            HStack(spacing: 12) {
                HeartRateStatItem(label: "Min", value: Int(stats.min))
                HeartRateStatItem(label: "Avg", value: Int(stats.average))
                HeartRateStatItem(label: "Max", value: Int(stats.max))
            }
        }
    }
}

struct HeartRateStatItem: View {
    let label: String
    let value: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
            Text("\(value)")
                .font(.caption)
                .bold()
        }
    }
}

struct StatInfoItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.subheadline)
                .bold()
        }
    }
}

struct SleepStageLegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct HeartRateStats {
    let min: Double
    let max: Double
    let average: Double
}

//#Preview {
//    Group {
//        if let session = try? PersistenceController.preview.container.viewContext.fetch(SleepSession.fetchRequest()).first {
//            SleepStagesChart(session: session)
//                .padding()
//        } else {
//            Text("No preview data available")
//        }
//    }
//}
