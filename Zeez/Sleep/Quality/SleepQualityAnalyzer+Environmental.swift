import CoreData
import os.log

extension SleepQualityAnalyzer {
    /// Enhanced environmental score calculation using the new analyzer
    func calculateEnhancedEnvironmentalScore() async throws -> Double {
        let enhancedScoring = EnhancedEnvironmentalScoring(context: context)
        let result = try await enhancedScoring.calculateScore(for: session)
        
        // Store additional analysis data
        if let note = createAnalysisNote(from: result) {
            session.addToNotes(note)
            try? context.save()
        }
        
        return result.score
    }
    
    private func createAnalysisNote(from result: EnvironmentalScoreResult) -> SleepNote? {
        let note = SleepNote(context: context)
        note.id = UUID()
        note.timestamp = Date()
        note.category = "environmental_analysis"
        
        // Format analysis details
        var content = """
        Environmental Analysis:
        Overall Score: \(String(format: "%.1f", result.score))
        
        Components:
        """
        
        for component in result.components {
            content += "\n• \(component.name): \(String(format: "%.1f", component.value))"
        }
        
        if !result.analysis.recommendations.isEmpty {
            content += "\n\nRecommendations:"
            for recommendation in result.analysis.recommendations {
                content += "\n• \(recommendation.description)"
            }
        }
        
        note.content = content
        return note
    }
}
