import CoreData
import Foundation
import os.log

/// Enhanced sleep quality analysis with personalization and confidence scoring
struct SleepQualityAnalysisResult {
    let heartRateScore: Double
    let movementScore: Double
    let environmentalScore: Double
    let respiratoryScore: Double
    let sleepCycleScore: Double
    let overallScore: Double
    let confidence: Double
    let personalizationLevel: PersonalizationLevel
    let calculationVersion: String
    let timestamp: Date
    
    enum PersonalizationLevel {
        case none       // Using standard thresholds
        case basic      // Some personalized ranges
        case advanced   // Fully personalized analysis
        case expert     // Deep learning from extensive history
    }
}

/// Responsible for calculating comprehensive sleep quality scores with personalization
class SleepQualityAnalyzer {
    let context: NSManagedObjectContext
    let session: SleepSession
    private let personalizationManager = PersonalizationManager.shared
    
    init(context: NSManagedObjectContext, session: SleepSession) {
        self.context = context
        self.session = session
    }
    
    /// Analyzes sleep session data and generates a personalized quality score
    func analyzeSleepQuality() async throws -> SleepQualityScore {
        // Get personalized ranges and confidence
        let personalizedConfidence = try await personalizationManager.calculateConfidenceScore(for: session)
        let personalizationLevel = determinePersonalizationLevel(confidence: personalizedConfidence)
        
        // Calculate component scores with personalization
        let heartRateScore = try await calculatePersonalizedHeartRateScore()
        let movementScore = try await calculatePersonalizedMovementScore()
        let environmentalScore = try await calculatePersonalizedEnvironmentalScore()
        let respiratoryScore = try await calculateRespiratoryScore()
        let sleepCycleScore = try await calculateSleepCycleScore()
        
        // Calculate overall score with adaptive weights based on personalization
        let overallScore = calculateAdaptiveOverallScore(
            heartRate: heartRateScore,
            movement: movementScore,
            environmental: environmentalScore,
            respiratory: respiratoryScore,
            sleepCycle: sleepCycleScore,
            confidence: personalizedConfidence
        )
        
        // Create and save Core Data entity for persistence (backward compatibility)
        let qualityEntity = SleepQualityScore(context: context)
        qualityEntity.id = UUID()
        qualityEntity.timestamp = Date()
        qualityEntity.calculationVersion = "3.0-personalized"
        qualityEntity.session = session
        qualityEntity.heartRateScore = heartRateScore.score
        qualityEntity.movementScore = movementScore.score
        qualityEntity.environmentalScore = environmentalScore.score
        qualityEntity.respiratoryScore = respiratoryScore
        qualityEntity.sleepCycleScore = sleepCycleScore
        qualityEntity.overallScore = overallScore
        
        // Store personalization metadata
        qualityEntity.confidenceScore = personalizedConfidence.overallScore
        qualityEntity.personalizationLevel = String(describing: personalizationLevel)
        qualityEntity.isPersonalized = heartRateScore.isPersonalized || movementScore.isPersonalized || environmentalScore.isPersonalized
        
        // Store which components used personalization (as JSON)
        let personalizedComponents = [
            "heartRate": heartRateScore.isPersonalized,
            "movement": movementScore.isPersonalized, 
            "environmental": environmentalScore.isPersonalized
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: personalizedComponents),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            qualityEntity.personalizedComponents = jsonString
        }
        
        try context.save()
        
        // Store enhanced analysis in session notes for debugging and insights
        try await storePersonalizationInsights(
            confidence: personalizedConfidence,
            personalizationLevel: personalizationLevel,
            componentScores: [
                "heartRate": heartRateScore,
                "movement": movementScore,
                "environmental": environmentalScore
            ]
        )
        
        return qualityEntity
    }
    
    /// Get enhanced analysis result with personalization details
    func getEnhancedAnalysisResult() async throws -> SleepQualityAnalysisResult {
        let personalizedConfidence = try await personalizationManager.calculateConfidenceScore(for: session)
        let personalizationLevel = determinePersonalizationLevel(confidence: personalizedConfidence)
        
        let heartRateScore = try await calculatePersonalizedHeartRateScore()
        let movementScore = try await calculatePersonalizedMovementScore()
        let environmentalScore = try await calculatePersonalizedEnvironmentalScore()
        let respiratoryScore = try await calculateRespiratoryScore()
        let sleepCycleScore = try await calculateSleepCycleScore()
        
        let overallScore = calculateAdaptiveOverallScore(
            heartRate: heartRateScore,
            movement: movementScore,
            environmental: environmentalScore,
            respiratory: respiratoryScore,
            sleepCycle: sleepCycleScore,
            confidence: personalizedConfidence
        )
        
        return SleepQualityAnalysisResult(
            heartRateScore: heartRateScore.score,
            movementScore: movementScore.score,
            environmentalScore: environmentalScore.score,
            respiratoryScore: respiratoryScore,
            sleepCycleScore: sleepCycleScore,
            overallScore: overallScore,
            confidence: personalizedConfidence.overallScore,
            personalizationLevel: personalizationLevel,
            calculationVersion: "3.0-personalized",
            timestamp: Date()
        )
    }
    
    // MARK: - Supporting Structures
    
    private struct PersonalizedScore {
        let score: Double
        let confidence: Double
        let isPersonalized: Bool
    }
    
    // MARK: - Personalization Level Determination
    
    private func determinePersonalizationLevel(confidence: PersonalizationConfidence) -> SleepQualityAnalysisResult.PersonalizationLevel {
        switch confidence.dataMaturity {
        case .insufficient:
            return .none
        case .developing:
            return .basic
        case .adequate:
            return .advanced
        case .mature:
            return .expert
        }
    }
    
    // MARK: - Personalized Score Calculations
    
    private func calculatePersonalizedHeartRateScore() async throws -> PersonalizedScore {
        guard let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
              !heartRateData.isEmpty else {
            return PersonalizedScore(score: 50.0, confidence: 0.0, isPersonalized: false)
        }
        
        do {
            // Get personalized heart rate range
            let personalizedRange = try await personalizationManager.getPersonalizedHeartRateRange()
            let heartRates = heartRateData.map { $0.value }
            
            // Calculate score based on how well heart rates fall within personalized optimal range
            let optimalRates = heartRates.filter { personalizedRange.contains($0) }
            let optimalRatio = Double(optimalRates.count) / Double(heartRates.count)
            
            // Calculate variability penalty (lower variability = better quality)
            let _ = heartRates.average ?? 0  // avgHeartRate - calculated for potential future use
            let variability = heartRates.standardDeviation ?? 0
            let variabilityScore = max(0, 100 - (variability * 2)) // Penalty for high variability
            
            let finalScore = (optimalRatio * 100 * 0.7) + (variabilityScore * 0.3)
            
            ZeezLogger.sleepTracking.debug("Personalized heart rate score: \(finalScore), range: \(personalizedRange)")
            
            return PersonalizedScore(score: finalScore, confidence: 85.0, isPersonalized: true)
            
        } catch {
            // Fall back to standard calculation
            return try await calculateStandardHeartRateScore()
        }
    }
    
    private func calculatePersonalizedMovementScore() async throws -> PersonalizedScore {
        guard let movementData = session.movementData?.allObjects as? [MovementData],
              !movementData.isEmpty else {
            return PersonalizedScore(score: 50.0, confidence: 0.0, isPersonalized: false)
        }
        
        // Use historical patterns to determine what constitutes "restful" movement for this user
        let activityLevels = movementData.map { Int($0.activityLevel) }
        
        // Calculate score based on periods of low movement (indicating restful sleep)
        let lowMovementPeriods = activityLevels.filter { $0 <= 2 }.count
        let movementScore = (Double(lowMovementPeriods) / Double(activityLevels.count)) * 100
        
        // Penalize excessive movement during sleep
        let highMovementPeriods = activityLevels.filter { $0 >= 7 }.count
        let movementPenalty = (Double(highMovementPeriods) / Double(activityLevels.count)) * 30
        
        let finalScore = max(0, movementScore - movementPenalty)
        
        return PersonalizedScore(score: finalScore, confidence: 75.0, isPersonalized: true)
    }
    
    private func calculatePersonalizedEnvironmentalScore() async throws -> PersonalizedScore {
        guard let environmentalData = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
              !environmentalData.isEmpty else {
            return PersonalizedScore(score: 50.0, confidence: 0.0, isPersonalized: false)
        }
        
        do {
            // Get personalized environmental preferences
            let personalizedRanges = try await personalizationManager.getPersonalizedEnvironmentalRanges()
            
            var environmentalScores: [Double] = []
            
            for reading in environmentalData {
                var readingScore = 100.0
                
                // Temperature scoring
                let tempDiff = abs(reading.temperature - personalizedRanges.optimalTemperature)
                if tempDiff > personalizedRanges.temperatureTolerance {
                    readingScore -= min(50, (tempDiff - personalizedRanges.temperatureTolerance) * 10)
                }
                
                // Noise scoring
                let noiseDiff = abs(reading.noiseLevel - personalizedRanges.optimalNoiseLevel)
                if noiseDiff > personalizedRanges.noiseTolerance {
                    readingScore -= min(30, (noiseDiff - personalizedRanges.noiseTolerance) * 2)
                }
                
                // Light scoring
                let lightDiff = abs(reading.lightLevel - personalizedRanges.optimalLightLevel)
                if lightDiff > personalizedRanges.lightTolerance {
                    readingScore -= min(20, (lightDiff - personalizedRanges.lightTolerance) * 3)
                }
                
                environmentalScores.append(max(0, readingScore))
            }
            
            let finalScore = environmentalScores.average ?? 50.0
            
            ZeezLogger.sleepTracking.debug("Personalized environmental score: \(finalScore)")
            
            return PersonalizedScore(score: finalScore, confidence: 80.0, isPersonalized: true)
            
        } catch {
            // Fall back to standard calculation
            return try await calculateStandardEnvironmentalScore()
        }
    }
    
    // MARK: - Adaptive Overall Score Calculation
    
    private func calculateAdaptiveOverallScore(
        heartRate: PersonalizedScore,
        movement: PersonalizedScore,
        environmental: PersonalizedScore,
        respiratory: Double,
        sleepCycle: Double,
        confidence: PersonalizationConfidence
    ) -> Double {
        // Adaptive weights based on confidence and personalization
        var weights: [Double] = [0.25, 0.25, 0.20, 0.15, 0.15] // Base weights
        
        // Increase weight for personalized components
        if heartRate.isPersonalized && heartRate.confidence > 70 {
            weights[0] = 0.30 // Increase heart rate weight
        }
        
        if movement.isPersonalized && movement.confidence > 70 {
            weights[1] = 0.30 // Increase movement weight
        }
        
        if environmental.isPersonalized && environmental.confidence > 70 {
            weights[2] = 0.25 // Increase environmental weight
        }
        
        // Normalize weights to sum to 1.0
        let totalWeight = weights.reduce(0, +)
        let normalizedWeights = weights.map { $0 / totalWeight }
        
        let weightedScores = [
            heartRate.score * normalizedWeights[0],
            movement.score * normalizedWeights[1],
            environmental.score * normalizedWeights[2],
            respiratory * normalizedWeights[3],
            sleepCycle * normalizedWeights[4]
        ]
        
        return weightedScores.reduce(0, +)
    }
    
    // MARK: - Personalization Insights Storage
    
    private func storePersonalizationInsights(
        confidence: PersonalizationConfidence,
        personalizationLevel: SleepQualityAnalysisResult.PersonalizationLevel,
        componentScores: [String: PersonalizedScore]
    ) async throws {
        let insightNote = SleepNote(context: context)
        insightNote.id = UUID()
        insightNote.timestamp = Date()
        insightNote.category = "personalization_analysis"
        
        let personalizedComponents = componentScores.compactMap { key, score in
            score.isPersonalized ? "\(key): \(String(format: "%.1f", score.score))% (personalized)" : nil
        }
        
        insightNote.content = """
        Personalization Analysis (v3.0)
        
        Personalization Level: \(personalizationLevel)
        Overall Confidence: \(String(format: "%.1f", confidence.overallScore))%
        Data Maturity: \(confidence.dataMaturity.description)
        
        Personalized Components: \(personalizedComponents.joined(separator: ", "))
        
        Confidence Factors:
        \(confidence.factors.map { "• \($0.key): \(String(format: "%.1f", $0.value))%" }.joined(separator: "\n"))
        """
        
        session.addToNotes(insightNote)
    }
    
    // MARK: - Standard Fallback Calculations
    
    private func calculateStandardHeartRateScore() async throws -> PersonalizedScore {
        guard let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
              !heartRateData.isEmpty else {
            return PersonalizedScore(score: 50.0, confidence: 0.0, isPersonalized: false)
        }
        
        // Sort data chronologically
        let sortedData = heartRateData.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        // Calculate metrics using standard ranges
        let heartRates = sortedData.map { $0.value }
        let _ = heartRates.average ?? 0  // avgHR - calculated for potential future use
        let variability = heartRates.standardDeviation ?? 0
        
        // Score based on standard healthy ranges (45-75 BPM during sleep)
        let standardRange = AppConstants.HealthMetrics.HeartRate.minimumSleep...AppConstants.HealthMetrics.HeartRate.maximumSleep
        let optimalRates = heartRates.filter { standardRange.contains($0) }
        let optimalRatio = Double(optimalRates.count) / Double(heartRates.count)
        
        let rangeScore = optimalRatio * 100
        let variabilityScore = max(0, 100 - (variability * 2))
        let finalScore = (rangeScore * 0.7) + (variabilityScore * 0.3)
        
        return PersonalizedScore(score: finalScore, confidence: 60.0, isPersonalized: false)
    }
    
    private func calculateStandardEnvironmentalScore() async throws -> PersonalizedScore {
        guard let environmentalData = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
              !environmentalData.isEmpty else {
            return PersonalizedScore(score: 50.0, confidence: 0.0, isPersonalized: false)
        }
        
        var environmentalScores: [Double] = []
        
        for reading in environmentalData {
            var readingScore = 100.0
            
            // Temperature scoring (18-24°C optimal)
            if reading.temperature < AppConstants.HealthMetrics.Environmental.minimumTemperature {
                readingScore -= (AppConstants.HealthMetrics.Environmental.minimumTemperature - reading.temperature) * 5
            } else if reading.temperature > AppConstants.HealthMetrics.Environmental.maximumTemperature {
                readingScore -= (reading.temperature - AppConstants.HealthMetrics.Environmental.maximumTemperature) * 5
            }
            
            // Noise scoring (20-50 dB optimal)
            if reading.noiseLevel > AppConstants.HealthMetrics.Environmental.maximumNoiseLevel {
                readingScore -= (reading.noiseLevel - AppConstants.HealthMetrics.Environmental.maximumNoiseLevel) * 2
            }
            
            // Light scoring (minimal light optimal)
            if reading.lightLevel > 10 {
                readingScore -= (reading.lightLevel - 10) * 3
            }
            
            environmentalScores.append(max(0, readingScore))
        }
        
        let finalScore = environmentalScores.average ?? 50.0
        return PersonalizedScore(score: finalScore, confidence: 50.0, isPersonalized: false)
    }
    
    // Legacy methods for backward compatibility - simplified implementations
    
    private func calculateRespiratoryScore() async throws -> Double {
        guard let respiratoryData = session.respiratoryData?.allObjects as? [RespiratoryData],
              !respiratoryData.isEmpty else {
            return 75.0 // Default score when no respiratory data available
        }
        
        let sortedData = respiratoryData.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        // Calculate respiratory metrics
        let avgRate = sortedData.reduce(0.0) { $0 + $1.respiratoryRate } / Double(sortedData.count)
        let avgOxygen = sortedData.compactMap { $0.oxygenSaturation }.reduce(0.0, +) / Double(sortedData.count)
        
        // Score based on healthy ranges
        var score = 100.0
        
        // Respiratory rate during sleep: 12-20 breaths per minute
        if avgRate < 12 || avgRate > 20 {
            score -= abs(avgRate - 16) * 3 // Penalty for deviation from optimal 16 bpm
        }
        
        // Oxygen saturation: should be >= 95%
        if avgOxygen < AppConstants.HealthMetrics.Respiratory.minimumOxygenSaturation {
            score -= (AppConstants.HealthMetrics.Respiratory.minimumOxygenSaturation - avgOxygen) * 10
        }
        
        return max(0, min(100, score))
    }
    
    private func calculateSleepCycleScore() async throws -> Double {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage],
              !stages.isEmpty else {
            return 60.0 // Default score when no stage data available
        }
        
        let sortedStages = stages.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
        
        // Calculate cycle completeness and timing
        let cycleScore = evaluateSleepCycles(sortedStages)
        let stageDistributionScore = evaluateStageDistribution(sortedStages)
        
        return (cycleScore + stageDistributionScore) / 2.0
    }
    
    // MARK: - Sleep Cycle Evaluation Helpers
    
    private func evaluateSleepCycles(_ stages: [SleepStage]) -> Double {
        // Simplified cycle evaluation based on stage transitions
        guard stages.count > 2 else { return 50.0 }
        
        var cycleQuality = 0.0
        let stageTypes = stages.compactMap { $0.stageType }
        
        // Check for presence of key sleep stages
        let hasLight = stageTypes.contains("LIGHT")
        let hasDeep = stageTypes.contains("DEEP") 
        let hasREM = stageTypes.contains("REM")
        
        if hasLight { cycleQuality += 30 }
        if hasDeep { cycleQuality += 35 }
        if hasREM { cycleQuality += 35 }
        
        return cycleQuality
    }
    
    private func evaluateStageDistribution(_ stages: [SleepStage]) -> Double {
        guard !stages.isEmpty else { return 50.0 }
        
        var totalDuration = 0.0
        var stageDurations: [String: Double] = [:]
        
        // Calculate total duration and time spent in each stage
        for stage in stages {
            guard let type = stage.stageType else { continue }
            stageDurations[type, default: 0] += stage.duration
            totalDuration += stage.duration
        }
        
        guard totalDuration > 0 else { return 50.0 }
        
        var score = 100.0
        
        // Simplified scoring based on reasonable sleep stage distributions
        for (stage, duration) in stageDurations {
            let percentage = (duration / totalDuration) * 100
            
            switch stage {
            case "LIGHT":
                // Light sleep should be 40-60% of total sleep
                if percentage < 40 || percentage > 60 {
                    score -= min(20, abs(percentage - 50) * 0.5)
                }
            case "DEEP":
                // Deep sleep should be 15-25% of total sleep
                if percentage < 15 || percentage > 25 {
                    score -= min(15, abs(percentage - 20) * 0.8)
                }
            case "REM":
                // REM sleep should be 20-30% of total sleep
                if percentage < 20 || percentage > 30 {
                    score -= min(15, abs(percentage - 25) * 0.6)
                }
            case "AWAKE":
                // Awake time should be minimal during sleep (< 10%)
                if percentage > 10 {
                    score -= (percentage - 10) * 2
                }
            default:
                break
            }
        }
        
        return max(0, score)
    }
}
