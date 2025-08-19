import SwiftUI
import CoreData
import os.log

/// Displays percentage breakdowns and metrics for sleep stages
struct SleepStageMetrics: View {
    private let stages: [SleepStage]
    
    init(stages: [SleepStage]) {
        self.stages = stages
    }
    
    private var stagePercentages: [(SleepStageType, Double)] {
        let totalDuration = stages.reduce(0.0) { $0 + $1.duration }
        var percentages: [SleepStageType: Double] = [:]
        
        // Calculate percentage for each stage type
        for stage in stages {
            guard let typeString = stage.stageType,
                  let type = SleepStageType(rawValue: typeString) else { continue }
            percentages[type, default: 0] += (stage.duration / totalDuration) * 100
        }
        
        // Convert to sorted array of tuples
        return SleepStageType.allCases
            .map { ($0, percentages[$0, default: 0]) }
            .sorted { $0.1 > $1.1 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stage Breakdown")
                .font(.headline)
            
            ForEach(stagePercentages, id: \.0) { stage, percentage in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stage.displayName)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(Int(round(percentage)))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geometry in 
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(stageColor(for: stage))
                                .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 8)
                        }
                    }
                    .frame(height: 8)
                    
                    Text(stage.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
    
    private func stageColor(for stage: SleepStageType) -> Color {
        switch stage {
        case .awake: return .gray
        case .lightSleep: return .blue
        case .deepSleep: return .indigo
        case .rem: return .purple
        }
    }
}

// MARK: - Preview Provider
struct SleepStageMetrics_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        return SleepStageMetrics(stages: createPreviewStages(context: context))
    }
    
    static func createPreviewStages(context: NSManagedObjectContext) -> [SleepStage] {
        let types: [SleepStageType] = [.lightSleep, .deepSleep, .rem, .lightSleep]
        let durations: [TimeInterval] = [7200, 10800, 3600, 7200]
        
        return zip(types, durations).map { type, duration in
            let stage = SleepStage(context: context)
            stage.id = UUID()
            stage.stageType = type.rawValue
            stage.duration = duration
            return stage
        }
    }
}
