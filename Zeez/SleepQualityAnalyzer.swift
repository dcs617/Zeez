import CoreData
import Foundation

/// Responsible for calculating comprehensive sleep quality scores
class SleepQualityAnalyzer {
    let context: NSManagedObjectContext
    let session: SleepSession
    
    init(context: NSManagedObjectContext, session: SleepSession) {
        self.context = context
        self.session = session
    }
    
    /// Analyzes sleep session data and generates a quality score
    func analyzeSleepQuality() async throws -> SleepQualityScore {
        let qualityScore = SleepQualityScore(context: context)
        qualityScore.id = UUID()
        qualityScore.timestamp = Date()
        qualityScore.calculationVersion = "2.0"
        qualityScore.session = session
        
        // Calculate component scores
        let heartRateScore = try await calculateHeartRateScore()
        let movementScore = try await calculateMovementScore()
        let environmentalScore = try await calculateEnvironmentalScore()
        let respiratoryScore = try await calculateRespiratoryScore()
        let sleepCycleScore = try await calculateSleepCycleScore()
        
        // Assign component scores
        qualityScore.heartRateScore = heartRateScore
        qualityScore.movementScore = movementScore
        qualityScore.environmentalScore = environmentalScore
        qualityScore.respiratoryScore = respiratoryScore
        qualityScore.sleepCycleScore = sleepCycleScore
        
        // Calculate overall score with weighted components
        qualityScore.overallScore = calculateOverallScore(
            heartRate: heartRateScore,
            movement: movementScore,
            environmental: environmentalScore,
            respiratory: respiratoryScore,
            sleepCycle: sleepCycleScore
        )
        
        try context.save()
        return qualityScore
    }
    
    private func calculateHeartRateScore() async throws -> Double {
        guard let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
              !heartRateData.isEmpty else {
            throw AppError.insufficientData
        }
        
        // Sort data chronologically
        let sortedData = heartRateData.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        // Calculate metrics
        let avgHR = sortedData.reduce(0.0) { $0 + $1.value } / Double(sortedData.count)
        let variability = calculateHeartRateVariability(sortedData)
        
        // Score based on healthy ranges
        let rangeScore = scoreHeartRateRange(average: avgHR)
        let variabilityScore = scoreHeartRateVariability(variability)
        
        return (rangeScore + variabilityScore) / 2.0
    }
    
    private func calculateMovementScore() async throws -> Double {
        guard let movementData = session.movementData?.allObjects as? [MovementData],
              !movementData.isEmpty else {
            throw AppError.insufficientData
        }
        
        let sortedData = movementData.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        // Calculate movement intensity
        let avgMagnitude = sortedData.reduce(0.0) { $0 + $1.magnitude } / Double(sortedData.count)
        let activityLevels = sortedData.map { Double($0.activityLevel) }
        let avgActivity = activityLevels.reduce(0.0, +) / Double(activityLevels.count)
        
        // Score based on optimal movement patterns
        return scoreMovementPatterns(magnitude: avgMagnitude, activity: avgActivity)
    }
    
    private func calculateEnvironmentalScore() async throws -> Double {
        guard let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
              !readings.isEmpty else {
            throw AppError.insufficientData
        }
        
        let sortedReadings = readings.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        // Calculate average environmental metrics
        let avgTemp = sortedReadings.compactMap { $0.temperature }.reduce(0.0, +) / Double(sortedReadings.count)
        let avgHumidity = sortedReadings.compactMap { $0.humidity }.reduce(0.0, +) / Double(sortedReadings.count)
        let avgNoise = sortedReadings.compactMap { $0.noiseLevel }.reduce(0.0, +) / Double(sortedReadings.count)
        let avgLight = sortedReadings.compactMap { $0.lightLevel }.reduce(0.0, +) / Double(sortedReadings.count)
        
        // Score each factor
        let tempScore = scoreTemperature(temp: avgTemp)
        let humidityScore = scoreHumidity(avgHumidity)
        let noiseScore = scoreNoise(avgNoise)
        let lightScore = scoreLight(avgLight)
        
        return try await calculateEnhancedEnvironmentalScore()
    }
    
    private func calculateRespiratoryScore() async throws -> Double {
        guard let respiratoryData = session.respiratoryData?.allObjects as? [RespiratoryData],
              !respiratoryData.isEmpty else {
            throw AppError.insufficientData
        }
        
        let sortedData = respiratoryData.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        // Calculate respiratory metrics
        let avgRate = sortedData.reduce(0.0) { $0 + $1.respiratoryRate } / Double(sortedData.count)
        let avgOxygen = sortedData.compactMap { $0.oxygenSaturation }.reduce(0.0, +) / Double(sortedData.count)
        
        return scoreRespiratoryMetrics(rate: avgRate, oxygen: avgOxygen)
    }
    
    private func calculateSleepCycleScore() async throws -> Double {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage],
              !stages.isEmpty else {
            throw AppError.insufficientData
        }
        
        let sortedStages = stages.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
        
        // Calculate cycle completeness and timing
        let cycleScore = evaluateSleepCycles(sortedStages)
        let stageDistributionScore = evaluateStageDistribution(sortedStages)
        
        return (cycleScore + stageDistributionScore) / 2.0
    }
    
    // MARK: - Scoring Helpers
    
    private func calculateHeartRateVariability(_ data: [HeartRateData]) -> Double {
        let values = data.map { $0.value }
        let mean = values.reduce(0.0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return sqrt(squaredDiffs.reduce(0.0, +) / Double(squaredDiffs.count))
    }
    
    private func scoreHeartRateRange(average: Double) -> Double {
        // Score based on healthy sleep heart rate ranges (40-100 bpm)
        switch average {
        case 40...60: return 100.0  // Optimal
        case 60...80: return 90.0   // Very good
        case 80...100: return 70.0  // Acceptable
        default: return 50.0        // Suboptimal
        }
    }
    
    private func scoreHeartRateVariability(_ variability: Double) -> Double {
        // Score based on typical HRV ranges during sleep
        switch variability {
        case 20...50: return 100.0  // Optimal
        case 15...20: return 90.0   // Very good
        case 10...15: return 80.0   // Good
        case 5...10: return 70.0    // Fair
        default: return 60.0        // Suboptimal
        }
    }
    
    private func scoreMovementPatterns(magnitude: Double, activity: Double) -> Double {
        // Lower movement is generally better during sleep
        let magnitudeScore = max(100 - (magnitude * 100), 0)
        let activityScore = max(100 - (activity * 20), 0)
        return (magnitudeScore + activityScore) / 2.0
    }
    
    private func scoreTemperature(temp: Double) -> Double {
        // Optimal sleeping temperature: 18-21°C (65-70°F)
        switch temp {
        case 18...21: return 100.0
        case 16...18, 21...23: return 90.0
        case 14...16, 23...25: return 80.0
        default: return 70.0
        }
    }
    
    private func scoreHumidity(_ humidity: Double) -> Double {
        // Optimal sleeping humidity: 30-50%
        switch humidity {
        case 30...50: return 100.0
        case 20...30, 50...60: return 90.0
        case 10...20, 60...70: return 80.0
        default: return 70.0
        }
    }
    
    private func scoreNoise(_ noise: Double) -> Double {
        // Optimal sleeping noise level: <30 dB
        switch noise {
        case 0...30: return 100.0
        case 30...40: return 90.0
        case 40...50: return 80.0
        case 50...60: return 70.0
        default: return 60.0
        }
    }
    
    private func scoreLight(_ light: Double) -> Double {
        // Optimal sleeping light level: <5 lux
        switch light {
        case 0...5: return 100.0
        case 5...10: return 90.0
        case 10...15: return 80.0
        case 15...20: return 70.0
        default: return 60.0
        }
    }
    
    private func scoreRespiratoryMetrics(rate: Double, oxygen: Double) -> Double {
        // Score respiratory rate (optimal: 12-20 breaths/min during sleep)
        let rateScore = switch rate {
        case 12...20: 100.0
        case 10...12, 20...22: 90.0
        case 8...10, 22...24: 80.0
        default: 70.0
        }
        
        // Score oxygen saturation (optimal: >95%)
        let oxygenScore = switch oxygen {
        case 95...100: 100.0
        case 90...95: 90.0
        case 85...90: 80.0
        default: 70.0
        }
        
        return (rateScore + oxygenScore) / 2.0
    }
    
    private func evaluateSleepCycles(_ stages: [SleepStage]) -> Double {
        // Analyze cycle completeness and transitions
        var score = 100.0
        var previousStage: String?
        
        for stage in stages {
            if let prev = previousStage {
                // Penalize inappropriate transitions
                if !isValidTransition(from: prev, to: stage.stageType ?? "") {
                    score -= 5.0
                }
            }
            previousStage = stage.stageType
        }
        
        return max(score, 0.0)
    }
    
    private func evaluateStageDistribution(_ stages: [SleepStage]) -> Double {
        var totalDuration = 0.0
        var stageDurations: [String: Double] = [:]
        
        // Calculate total duration and time spent in each stage
        for stage in stages {
            guard let type = stage.stageType else { continue }
            stageDurations[type, default: 0] += stage.duration
            totalDuration += stage.duration
        }
        
        // Ideal distribution (approximate):
        // Light: 45-55%
        // Deep: 15-25%
        // REM: 20-25%
        // Awake: 5-10%
        
        var score = 100.0
        
        for (stage, duration) in stageDurations {
            let percentage = (duration / totalDuration) * 100
            score -= deviationPenalty(for: stage, percentage: percentage)
        }
        
        return max(score, 0.0)
    }
    
    private func deviationPenalty(for stage: String, percentage: Double) -> Double {
        switch stage {
        case "LIGHT":
            return abs(percentage - 50) > 5 ? abs(percentage - 50) : 0
        case "DEEP":
            return abs(percentage - 20) > 5 ? abs(percentage - 20) : 0
        case "REM":
            return abs(percentage - 22.5) > 5 ? abs(percentage - 22.5) : 0
        case "AWAKE":
            return percentage > 10 ? (percentage - 10) * 2 : 0
        default:
            return 0
        }
    }
    
    private func isValidTransition(from: String, to: String) -> Bool {
        // Define valid stage transitions
        let validTransitions: [String: Set<String>] = [
            "AWAKE": ["LIGHT"],
            "LIGHT": ["DEEP", "REM", "AWAKE"],
            "DEEP": ["LIGHT", "AWAKE"],
            "REM": ["LIGHT", "AWAKE"]
        ]
        
        return validTransitions[from]?.contains(to) ?? false
    }
    
    private func calculateOverallScore(
        heartRate: Double,
        movement: Double,
        environmental: Double,
        respiratory: Double,
        sleepCycle: Double
    ) -> Double {
        // Weighted average of component scores
        let weights: [Double] = [0.25, 0.20, 0.15, 0.20, 0.20]
        let scores = [heartRate, movement, environmental, respiratory, sleepCycle]
        
        let weightedSum = zip(scores, weights).reduce(0.0) { $0 + ($1.0 * $1.1) }
        return min(max(weightedSum, 0), 100) // Ensure score is between 0-100
    }
}
