import SwiftUI
import Charts
import CoreData
import os.log

struct SleepCyclesChart: View {
    let session: SleepSession
    
    internal var stageColors: [SleepStageType: Color] = [
        .awake: Color(red: 0.95, green: 0.8, blue: 0.5),      // Soft Yellow
        .lightSleep: Color(red: 0.7, green: 0.85, blue: 0.9), // Light Blue
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
                  let stageType = stage.stageType,
                  let type = SleepStageType(rawValue: stageType) else { return nil }
            
            return (type, startTime, stage.duration)
        }.sorted { $0.startTime < $1.startTime }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Cycles")
                .font(.headline)
            
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
                    .chartYScale(domain: 0...3)
                    .chartYAxis {
                        AxisMarks(values: [0, 1, 2, 3]) { value in
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
                HeartRateStatsBox(stats: heartRateMetrics)
                    .padding(8)
                    .background(Color(UIColor.systemBackground).opacity(0.9))
                    .cornerRadius(8)
                    .padding(8)
            }
            
            // Legend
            HStack(spacing: 16) {
                ForEach(SleepStageType.allCases, id: \.self) { stage in
                    SleepStageLegendItem(color: stageColors[stage] ?? .gray, label: stage.displayName)
                }
            }
            .padding(.top, 8)
            
            // Sleep Duration Info
            if let startTime = session.startTime,
               let endTime = session.endTime {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sleep Duration")
                        .font(.subheadline)
                        .bold()
                    
                    HStack(spacing: 20) {
                        StatInfoItem(
                            label: "Time in Bed",
                            value: formatDuration(endTime.timeIntervalSince(startTime))
                        )
                        
                        StatInfoItem(
                            label: "Total Sleep",
                            value: formatDuration(calculateTotalSleepTime())
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
        case .awake: return 3
        case .rem: return 2
        case .lightSleep: return 1
        case .deepSleep: return 0
        }
    }
    
    private func stageLabelForValue(_ value: Int) -> String {
        switch value {
        case 0: return "Deep"
        case 1: return "Light"
        case 2: return "REM"
        case 3: return "Awake"
        default: return ""
        }
    }
    
    private func calculateTotalSleepTime() -> TimeInterval {
        stageData
            .filter { $0.stage != .awake }
            .reduce(0) { $0 + $1.duration }
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
//            SleepCyclesChart(session: session)
//                .padding()
//        } else {
//            Text("No preview data available")
//        }
//    }
//}
