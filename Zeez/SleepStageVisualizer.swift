import SwiftUI
import CoreData

/// Displays a visual timeline of sleep stages
struct SleepStageVisualizer: View {
    private let stages: [SleepStage]
    private let totalDuration: TimeInterval
    
    init(stages: [SleepStage], totalDuration: TimeInterval) {
        self.stages = stages
        self.totalDuration = totalDuration
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stages")
                .font(.headline)
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(stages) { stage in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(stageColor(for: stage))
                            .frame(width: stageWidth(for: stage, in: geometry))
                    }
                }
                .frame(height: 24)
            }
            .frame(height: 24)
            
            stageLegend
        }
        .padding()
    }
    
    private func stageWidth(for stage: SleepStage, in geometry: GeometryProxy) -> CGFloat {
        let proportion = stage.duration / totalDuration
        return geometry.size.width * CGFloat(proportion)
    }
    
    private func stageColor(for stage: SleepStage) -> Color {
        guard let typeString = stage.stageType,
              let type = SleepStageType(rawValue: typeString) else {
            return .gray
        }
        
        switch type {
        case .awake: return .gray
        case .lightSleep: return .blue
        case .deepSleep: return .indigo
        case .rem: return .purple
        }
    }
    
    private var stageLegend: some View {
        HStack(spacing: 16) {
            ForEach(SleepStageType.allCases, id: \.self) { stage in
                HStack(spacing: 4) {
                    Circle()
                        .fill(stageColor(for: createDummyStage(type: stage)))
                        .frame(width: 8, height: 8)
                    
                    Text(stage.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // Helper to create a dummy stage for legend colors
    private func createDummyStage(type: SleepStageType) -> SleepStage {
        let stage = SleepStage(context: PersistenceController.shared.container.viewContext)
        stage.stageType = type.rawValue
        return stage
    }
}

// MARK: - Preview Provider
struct SleepStageVisualizer_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let stages = createPreviewStages(context: context)
        return SleepStageVisualizer(stages: stages, totalDuration: 28800) // 8 hours
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