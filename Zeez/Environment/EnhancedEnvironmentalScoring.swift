import CoreData
import Foundation
import os.log

/// Handles enhanced environmental scoring with historical context
class EnhancedEnvironmentalScoring {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Calculate environmental score with historical context
    func calculateScore(for session: SleepSession) async throws -> EnvironmentalScoreResult {
        // Get current session analysis
        let analyzer = EnvironmentalAnalyzer(context: context)
        let analysis = try await analyzer.analyzeSession(session)
        
        // Calculate base score
        let baseScore = calculateBaseScore(from: analysis)
        
        // Get historical context
        let optimal = try await analyzer.findOptimalConditions()
        let historicalImpact = calculateHistoricalImpact(
            current: analysis,
            optimal: optimal
        )
        
        // Calculate trend impact
        let trendImpact = try await calculateTrendImpact(
            for: session,
            currentAnalysis: analysis
        )
        
        // Calculate final score with adjustments
        let finalScore = adjustScore(
            baseScore: baseScore,
            historicalImpact: historicalImpact,
            trendImpact: trendImpact
        )
        
        // Save recommendations if score is below threshold
        if finalScore < 80 {
            EnvironmentalRecommendationTracker.shared.saveRecommendations(
                analysis.recommendations,
                for: session
            )
        }
        
        return EnvironmentalScoreResult(
            score: finalScore,
            baseScore: baseScore,
            historicalImpact: historicalImpact,
            trendImpact: trendImpact,
            analysis: analysis
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateBaseScore(from analysis: EnvironmentalAnalysis) -> Double {
        let temperatureScore = scoreMetric(
            analysis.temperature,
            optimalRange: 18...22,
            toleranceRange: 16...24
        )
        
        let humidityScore = scoreMetric(
            analysis.humidity,
            optimalRange: 30...50,
            toleranceRange: 20...60
        )
        
        let noiseScore = scoreMetric(
            analysis.noise,
            optimalRange: 0...30,
            toleranceRange: 0...50
        )
        
        let lightScore = scoreMetric(
            analysis.light,
            optimalRange: 0...5,
            toleranceRange: 0...15
        )
        
        // Weight the scores
        return (temperatureScore * 0.3) +
               (humidityScore * 0.25) +
               (noiseScore * 0.25) +
               (lightScore * 0.2)
    }
    
    private func scoreMetric(
        _ metrics: EnvironmentalStatistics,
        optimalRange: ClosedRange<Double>,
        toleranceRange: ClosedRange<Double>
    ) -> Double {
        let baseScore: Double
        if optimalRange.contains(metrics.average) {
            baseScore = 100.0
        } else if toleranceRange.contains(metrics.average) {
            let deviation = min(
                abs(metrics.average - toleranceRange.lowerBound),
                abs(metrics.average - toleranceRange.upperBound)
            )
            let range = toleranceRange.upperBound - toleranceRange.lowerBound
            baseScore = 80.0 - (deviation / range) * 30.0
        } else {
            baseScore = 50.0
        }
        
        // Apply variance penalty
        let variancePenalty = min(metrics.variance * 2, 20.0)
        return max(baseScore - variancePenalty, 0)
    }

    private func calculateHistoricalImpact(
        current: EnvironmentalAnalysis,
        optimal: OptimalConditions
    ) -> Double {
        var impact = 0.0
        
        // Compare current conditions to historical optimal ranges
        if optimal.temperature.contains(current.temperature.average) {
            impact += 5.0
        }
        if optimal.humidity.contains(current.humidity.average) {
            impact += 5.0
        }
        if optimal.noise.contains(current.noise.average) {
            impact += 5.0
        }
        if optimal.light.contains(current.light.average) {
            impact += 5.0
        }
        
        return impact
    }
    
    private func calculateTrendImpact(
        for session: SleepSession,
        currentAnalysis: EnvironmentalAnalysis
    ) async throws -> Double {
        // Get recent sessions
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        guard let startTime = session.startTime else { return 0.0 }
        
        request.predicate = NSPredicate(
            format: "endTime < %@ AND qualityScore > 0",
            startTime as CVarArg
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SleepSession.endTime, ascending: false)
        ]
        request.fetchLimit = 7 // Last week
        
        let recentSessions = try context.fetch(request)
        
        // Calculate trend impact based on environmental score improvements
        var impact = 0.0
        if !recentSessions.isEmpty {
            let recentScores = recentSessions.compactMap { $0.environmentalScore }
            if let avgRecentScore = recentScores.average {
                // Positive trend bonus
                let currentCorrelation = (
                    currentAnalysis.qualityCorrelation.temperatureImpact +
                    currentAnalysis.qualityCorrelation.humidityImpact +
                    currentAnalysis.qualityCorrelation.noiseImpact +
                    currentAnalysis.qualityCorrelation.lightImpact
                ) / 4.0 * 100
                
                if currentCorrelation > avgRecentScore {
                    impact += 5.0
                }
                
                // Consistency bonus
                if let stdDev = recentScores.standardDeviation,
                   stdDev < 10 {
                    impact += 5.0
                }
            }
        }
        
        return impact
    }
    
    private func adjustScore(
        baseScore: Double,
        historicalImpact: Double,
        trendImpact: Double
    ) -> Double {
        // Apply impacts and ensure score stays within bounds
        return min(max(baseScore + historicalImpact + trendImpact, 0), 100)
    }
}

// MARK: - Supporting Types

struct EnvironmentalScoreResult {
    let score: Double
    let baseScore: Double
    let historicalImpact: Double
    let trendImpact: Double
    let analysis: EnvironmentalAnalysis
    
    var components: [ScoreComponent] {
        [
            ScoreComponent(name: "Base Score", value: baseScore),
            ScoreComponent(name: "Historical Context", value: historicalImpact),
            ScoreComponent(name: "Trend Impact", value: trendImpact)
        ]
    }
}

struct ScoreComponent {
    let name: String
    let value: Double
}
