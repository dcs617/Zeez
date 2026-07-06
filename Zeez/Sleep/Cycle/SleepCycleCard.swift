import SwiftUI
import os.log

struct SleepCycleCard: View {
    let session: SleepSession?
    
    private let sleepStageColors: [SleepStageType: Color] = [
        .awake: .yellow.opacity(0.8),
        .rem: Color(red: 0.3, green: 0.2, blue: 0.5),   // Dark Purple
        .lightSleep: Color(red: 0.4, green: 0.8, blue: 0.6),  // Light Green
        .asleepUnspecified: .teal.opacity(0.8),
        .deepSleep: Color(red: 0.2, green: 0.4, blue: 0.8)    // Deep Blue
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Cycles Through the Night")
                .font(.headline)
            
            HStack(spacing: 20) {
                // Pie Chart
                ZStack {
                    Circle()
                        .fill(.clear)
                        .frame(width: 120, height: 120)
                        .overlay(
                            PieChartView(
                                stages: getSleepStages(),
                                colors: sleepStageColors
                            )
                        )
                    
                    Text("The\nSleep\nCycle")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                }
                
                // Bar Chart
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(getSleepStages()) { stage in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(sleepStageColors[stage.type] ?? .gray)
                                .frame(width: 8, height: 8)
                            
                            Text(stage.type.displayName)
                                .font(.caption)
                            
                            Spacer()
                            
                            Text("\(Int(stage.duration / 60)) min")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            // Time-based bar chart
            TimeBarChartView(stages: getSleepStages(), colors: sleepStageColors)
                .frame(height: 100)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func getSleepStages() -> [SleepStageInfo] {
        guard let stages = session?.sleepStages?.allObjects as? [SleepStage] else {
            return []
        }
        
        return stages.compactMap { stage in
            if let type = stage.stageType,
               let stageType = SleepStageType.normalize(type) {
                return SleepStageInfo(
                    type: stageType,
                    duration: stage.duration,
                    startTime: stage.startTime ?? Date(),
                    endTime: stage.endTime ?? Date()
                )
            }
            return nil
        }

    }
}

struct PieChartView: View {
    let stages: [SleepStageInfo]
    let colors: [SleepStageType: Color]
    
    private var totalDuration: TimeInterval {
        stages.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) * 0.5
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            
            var startAngle = Angle.degrees(-90)
            for stage in stages {
                let angle = Angle.degrees(360 * (stage.duration / totalDuration))
                let endAngle = startAngle + angle
                
                let path = Path { p in
                    p.move(to: center)
                    p.addArc(center: center, radius: radius,
                            startAngle: startAngle, endAngle: endAngle, clockwise: false)
                    p.closeSubpath()
                }
                
                context.fill(path, with: .color(colors[stage.type] ?? .gray))
                
                startAngle = endAngle
            }
        }
    }
}

struct TimeBarChartView: View {
    let stages: [SleepStageInfo]
    let colors: [SleepStageType: Color]
    
    var body: some View {
        let timeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "ha"
            return formatter
        }()
        
        VStack(spacing: 4) {
            GeometryReader { geometry in
                if let startTime = stages.first?.startTime,
                   let endTime = stages.last?.endTime {
                    
                    let totalDuration = endTime.timeIntervalSince(startTime)
                    
                    ZStack(alignment: .leading) {
                        ForEach(stages) { stage in
                            let xOffset = geometry.size.width * CGFloat(stage.startTime.timeIntervalSince(startTime) / totalDuration)
                            let width = geometry.size.width * CGFloat(stage.duration / totalDuration)
                            
                            Rectangle()
                                .fill(colors[stage.type] ?? .gray)
                                .frame(width: max(width, 1))
                                .offset(x: xOffset)
                        }
                    }
                    
                    // Time labels
                    HStack {
                        Text(timeFormatter.string(from: startTime))
                        Spacer()
                        Text(timeFormatter.string(from: endTime))
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
            }
        }
    }
}

struct SleepStageInfo: Identifiable {
    let id = UUID()
    let type: SleepStageType
    let duration: TimeInterval
    var startTime: Date
    var endTime: Date
}
