import SwiftUI
import Charts
import os.log

public struct CycleVisualization: View {
    let stages: [SleepStage]
    let idealCycles: [IdealCycle]
    @State private var selectedStage: SleepStage?
    
    public init(stages: [SleepStage], idealCycles: [IdealCycle]) {
        self.stages = stages
        self.idealCycles = idealCycles
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                // Actual sleep stages
                ForEach(stages) { stage in
                    BarMark(
                        x: .value("Time", stage.startTime ?? Date()),
                        y: .value("Stage", stageValue(for: stage.stageType ?? "")),
                        width: .fixed(8)
                    )
                    .foregroundStyle(stageColor(stage.stageType ?? ""))
                }
                
                // Ideal cycle overlay (dashed line)
                ForEach(idealCycles) { cycle in
                    LineMark(
                        x: .value("Time", cycle.time),
                        y: .value("Stage", cycle.stageValue)
                    )
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                
                if let selected = selectedStage {
                    RuleMark(
                        x: .value("Selected", selected.startTime ?? Date())
                    )
                    .foregroundStyle(.gray.opacity(0.3))
                }
            }
            .frame(height: 200)
            .chartYScale(domain: 0...3)
            .chartYAxis {
                AxisMarks(values: [0, 1, 2, 3]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        Text(stageName(for: value.index))
                            .font(.caption)
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    updateSelectedStage(at: value.location,
                                                      proxy: proxy,
                                                      geometry: geometry)
                                }
                        )
                }
            }
            
            // Legend
            HStack(spacing: 12) {
                ForEach(stageTypes, id: \.self) { stage in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(stageColor(stage))
                            .frame(width: 8, height: 8)
                        Text(stage.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    private func updateSelectedStage(at location: CGPoint,
                                   proxy: ChartProxy,
                                   geometry: GeometryProxy) {
        guard let date = proxy.value(atX: location.x) as Date? else { return }
        
        selectedStage = stages.min { stage1, stage2 in
            abs((stage1.startTime ?? Date()).timeIntervalSince(date)) < 
            abs((stage2.startTime ?? Date()).timeIntervalSince(date))
        }
    }
    
    private func stageValue(for type: String) -> Double {
        switch type {
        case "DEEP": return 0
        case "LIGHT": return 1
        case "REM": return 2
        case "AWAKE": return 3
        default: return 0
        }
    }
    
    private func stageName(for value: Int) -> String {
        switch value {
        case 0: return "Deep"
        case 1: return "Light"
        case 2: return "REM"
        case 3: return "Awake"
        default: return ""
        }
    }
    
    private func stageColor(_ type: String) -> Color {
        switch type {
        case "DEEP": return .indigo
        case "LIGHT": return .blue
        case "REM": return .purple
        case "AWAKE": return .orange
        default: return .gray
        }
    }
    
    private var stageTypes = ["DEEP", "LIGHT", "REM", "AWAKE"]
}

public struct IdealCycle: Identifiable {
    public let id = UUID()
    let time: Date
    let stageValue: Double
}

struct CycleQualityCard: View {
    let title: String
    let score: Double
    let icon: String
    let trend: HeartRateTrendDirection
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(scoreColor)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(Int(score))%")
                        .font(.title3)
                        .bold()
                    
                    Image(systemName: trend.icon)
                        .font(.caption)
                        .foregroundStyle(trend.color)
                }
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(scoreColor.gradient)
                        .frame(width: geometry.size.width * CGFloat(score / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
        }
    }
    
    private var scoreColor: Color {
        switch score {
        case 90...: return .green
        case 70..<90: return .blue
        case 50..<70: return .yellow
        default: return .red
        }
    }
}

struct CycleInsightRow: View {
    let title: String
    let message: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            CycleQualityCard(
                title: "Cycle Quality",
                score: 85,
                icon: "waveform.path.ecg",
                trend: .up,
                description: "Your sleep cycles are following a healthy pattern"
            )
            
            CycleInsightRow(
                title: "Consistent Cycles",
                message: "Your sleep cycles show good regularity, which indicates quality rest",
                icon: "checkmark.circle.fill",
                color: .green
            )
        }
        .padding()
    }
}
