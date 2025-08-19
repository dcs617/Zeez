import CoreData
import Combine
import os.log

/// Responsible for analyzing sleep data to detect and classify sleep stages
class SleepStageAnalyzer {
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Analyzes a sleep session to determine sleep stages
    /// - Parameter session: The sleep session to analyze
    /// - Returns: Array of classified sleep stages
    func analyzeSleepStages(for session: SleepSession) async throws -> [SleepStage] {
        guard let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
              let movementData = session.movementData?.allObjects as? [MovementData],
              let respiratoryData = session.respiratoryData?.allObjects as? [RespiratoryData] else {
            throw AppError.insufficientData
        }
        
        // Sort data chronologically
        let sortedHeartRate = heartRateData.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
        let sortedMovement = movementData.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
        let sortedRespiratory = respiratoryData.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
        
        // Analyze in 30-minute epochs
        let epochs = try await createEpochs(
            heartRate: sortedHeartRate,
            movement: sortedMovement,
            respiratory: sortedRespiratory
        )
        
        return try await classifyStages(epochs: epochs, session: session)
    }
    
    /// Creates analysis epochs from sensor data
    private func createEpochs(
        heartRate: [HeartRateData],
        movement: [MovementData],
        respiratory: [RespiratoryData]
    ) async throws -> [SleepEpoch] {
        // Implementation will analyze data in 30-minute windows
        var epochs: [SleepEpoch] = []
        let epochDuration: TimeInterval = AppConstants.SleepCycle.epochDuration // 30 minutes
        
        guard let startTime = heartRate.first?.timestamp,
              let endTime = heartRate.last?.timestamp else {
            throw AppError.insufficientData
        }
        
        var currentTime = startTime
        while currentTime < endTime {
            let epochEnd = currentTime.addingTimeInterval(epochDuration)
            
            // Filter data for current epoch
            let epochHeartRate = heartRate.filter { 
                guard let timestamp = $0.timestamp else { return false }
                return timestamp >= currentTime && timestamp < epochEnd
            }
            
            let epochMovement = movement.filter {
                guard let timestamp = $0.timestamp else { return false }
                return timestamp >= currentTime && timestamp < epochEnd
            }
            
            let epochRespiratory = respiratory.filter {
                guard let timestamp = $0.timestamp else { return false }
                return timestamp >= currentTime && timestamp < epochEnd
            }
            
            // Create epoch with filtered data
            let epoch = SleepEpoch(
                startTime: currentTime,
                endTime: epochEnd,
                heartRateData: epochHeartRate,
                movementData: epochMovement,
                respiratoryData: epochRespiratory
            )
            
            epochs.append(epoch)
            currentTime = epochEnd
        }
        
        return epochs
    }
    
    /// Classifies sleep stages based on analyzed epochs
    private func classifyStages(epochs: [SleepEpoch], session: SleepSession) async throws -> [SleepStage] {
        var stages: [SleepStage] = []
        
        for epoch in epochs {
            let stage = try await determineStage(from: epoch)
            
            // Create CoreData SleepStage entity
            let sleepStage = SleepStage(context: context)
            sleepStage.id = UUID()
            sleepStage.startTime = epoch.startTime
            sleepStage.endTime = epoch.endTime
            sleepStage.duration = epoch.endTime.timeIntervalSince(epoch.startTime)
            sleepStage.stageType = stage.rawValue
            sleepStage.confidence = calculateConfidence(for: epoch)
            sleepStage.session = session
            
            stages.append(sleepStage)
        }
        
        try context.save()
        return stages
    }
    
    /// Determines sleep stage from epoch data using enhanced multi-factor analysis
    private func determineStage(from epoch: SleepEpoch) async throws -> SleepStageType {
        guard !epoch.heartRateData.isEmpty,
              !epoch.movementData.isEmpty,
              !epoch.respiratoryData.isEmpty else {
            return .awake // Default to awake if insufficient data
        }
        
        // Calculate comprehensive metrics
        let hrMetrics = calculateHeartRateMetrics(epoch.heartRateData)
        let movementMetrics = calculateMovementMetrics(epoch.movementData)
        let respiratoryMetrics = calculateRespiratoryMetrics(epoch.respiratoryData)
        
        // Multi-factor scoring approach
        let stageScores = calculateStageScores(
            heartRate: hrMetrics,
            movement: movementMetrics,
            respiratory: respiratoryMetrics
        )
        
        // Return stage with highest confidence score
        return stageScores.max(by: { $0.value < $1.value })?.key ?? .awake
    }
    
    /// Calculate comprehensive heart rate metrics for stage detection
    private func calculateHeartRateMetrics(_ data: [HeartRateData]) -> HeartRateMetrics {
        let values = data.map { $0.value }
        let average = values.reduce(0, +) / Double(values.count)
        
        // Calculate HRV (simplified RMSSD)
        let hrv = calculateHRV(values)
        
        // Calculate trend (increasing/decreasing/stable)
        let trend = calculateTrend(values)
        
        return HeartRateMetrics(
            average: average,
            hrv: hrv,
            trend: trend,
            stability: calculateStability(values)
        )
    }
    
    /// Calculate movement metrics with acceleration analysis
    private func calculateMovementMetrics(_ data: [MovementData]) -> MovementMetrics {
        let magnitudes = data.map { $0.magnitude }
        let activities = data.map { Double($0.activityLevel) }
        
        let avgMagnitude = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let avgActivity = activities.reduce(0, +) / Double(activities.count)
        
        // Calculate movement variability
        let variability = calculateVariability(magnitudes)
        
        // Detect periodic movements (rolling/position changes)
        let periodicMovements = detectPeriodicMovements(data)
        
        return MovementMetrics(
            avgMagnitude: avgMagnitude,
            avgActivity: avgActivity,
            variability: variability,
            periodicMovements: periodicMovements
        )
    }
    
    /// Calculate respiratory metrics for stage classification
    private func calculateRespiratoryMetrics(_ data: [RespiratoryData]) -> RespiratoryMetrics {
        let rates = data.map { $0.respiratoryRate }
        let avgRate = rates.reduce(0, +) / Double(rates.count)
        
        let oxygenLevels = data.compactMap { $0.oxygenSaturation }
        let avgOxygen = oxygenLevels.isEmpty ? 0 : oxygenLevels.reduce(0, +) / Double(oxygenLevels.count)
        
        return RespiratoryMetrics(
            avgRate: avgRate,
            avgOxygen: avgOxygen,
            variability: calculateVariability(rates),
            regularity: calculateRegularity(rates)
        )
    }
    
    /// Calculate probability scores for each sleep stage
    private func calculateStageScores(
        heartRate: HeartRateMetrics,
        movement: MovementMetrics,
        respiratory: RespiratoryMetrics
    ) -> [SleepStageType: Double] {
        var scores: [SleepStageType: Double] = [:]
        
        // Deep Sleep scoring
        scores[.deepSleep] = calculateDeepSleepScore(
            heartRate: heartRate,
            movement: movement,
            respiratory: respiratory
        )
        
        // Light Sleep scoring
        scores[.lightSleep] = calculateLightSleepScore(
            heartRate: heartRate,
            movement: movement,
            respiratory: respiratory
        )
        
        // REM Sleep scoring
        scores[.rem] = calculateREMScore(
            heartRate: heartRate,
            movement: movement,
            respiratory: respiratory
        )
        
        // Awake scoring
        scores[.awake] = calculateAwakeScore(
            heartRate: heartRate,
            movement: movement,
            respiratory: respiratory
        )
        
        return scores
    }
    
    // MARK: - Stage-specific scoring methods
    
    private func calculateDeepSleepScore(
        heartRate: HeartRateMetrics,
        movement: MovementMetrics,
        respiratory: RespiratoryMetrics
    ) -> Double {
        var score = 0.0
        
        // Low heart rate (40-60 bpm)
        if heartRate.average >= 40 && heartRate.average <= 60 {
            score += 25.0
        } else if heartRate.average <= 70 {
            score += 15.0
        }
        
        // High HRV indicates parasympathetic dominance
        if heartRate.hrv > 30 {
            score += 20.0
        } else if heartRate.hrv > 20 {
            score += 10.0
        }
        
        // Minimal movement
        if movement.avgMagnitude < 0.1 {
            score += 25.0
        } else if movement.avgMagnitude < 0.2 {
            score += 15.0
        }
        
        // Slow, regular breathing
        if respiratory.avgRate >= 12 && respiratory.avgRate <= 16 && respiratory.regularity > 0.8 {
            score += 20.0
        }
        
        // High stability across all metrics
        if heartRate.stability > 0.8 && movement.variability < 0.3 {
            score += 10.0
        }
        
        return score
    }
    
    private func calculateLightSleepScore(
        heartRate: HeartRateMetrics,
        movement: MovementMetrics,
        respiratory: RespiratoryMetrics
    ) -> Double {
        var score = 0.0
        
        // Moderate heart rate (60-80 bpm)
        if heartRate.average >= 60 && heartRate.average <= 80 {
            score += 20.0
        }
        
        // Moderate HRV
        if heartRate.hrv >= 15 && heartRate.hrv <= 35 {
            score += 15.0
        }
        
        // Low to moderate movement
        if movement.avgMagnitude >= 0.1 && movement.avgMagnitude <= 0.3 {
            score += 20.0
        }
        
        // Some periodic movements allowed
        if movement.periodicMovements <= 3 {
            score += 15.0
        }
        
        // Normal respiratory rate
        if respiratory.avgRate >= 14 && respiratory.avgRate <= 18 {
            score += 15.0
        }
        
        // Moderate stability
        if heartRate.stability >= 0.6 && heartRate.stability <= 0.8 {
            score += 15.0
        }
        
        return score
    }
    
    private func calculateREMScore(
        heartRate: HeartRateMetrics,
        movement: MovementMetrics,
        respiratory: RespiratoryMetrics
    ) -> Double {
        var score = 0.0
        
        // Higher heart rate (70-90 bpm)
        if heartRate.average >= 70 && heartRate.average <= 90 {
            score += 25.0
        }
        
        // Variable heart rate (low stability)
        if heartRate.stability < 0.6 {
            score += 20.0
        }
        
        // Minimal movement (muscle atonia)
        if movement.avgMagnitude < 0.15 {
            score += 25.0
        }
        
        // Irregular breathing
        if respiratory.variability > 0.4 {
            score += 15.0
        }
        
        // Higher respiratory rate
        if respiratory.avgRate > 16 {
            score += 15.0
        }
        
        return score
    }
    
    private func calculateAwakeScore(
        heartRate: HeartRateMetrics,
        movement: MovementMetrics,
        respiratory: RespiratoryMetrics
    ) -> Double {
        var score = 0.0
        
        // Higher heart rate
        if heartRate.average > 80 {
            score += 20.0
        }
        
        // Significant movement
        if movement.avgMagnitude > 0.3 {
            score += 30.0
        }
        
        // High activity level
        if movement.avgActivity > 2.0 {
            score += 25.0
        }
        
        // Multiple position changes
        if movement.periodicMovements > 5 {
            score += 15.0
        }
        
        // Variable respiratory patterns
        if respiratory.variability > 0.5 {
            score += 10.0
        }
        
        return score
    }
    
    // MARK: - Helper Methods
    
    /// Calculate Heart Rate Variability using simplified RMSSD
    private func calculateHRV(_ heartRates: [Double]) -> Double {
        guard heartRates.count > 1 else { return 0 }
        
        var sumSquareDifferences = 0.0
        for i in 1..<heartRates.count {
            let diff = heartRates[i] - heartRates[i-1]
            sumSquareDifferences += diff * diff
        }
        
        let meanSquareDifference = sumSquareDifferences / Double(heartRates.count - 1)
        return sqrt(meanSquareDifference)
    }
    
    /// Calculate trend direction in data series
    private func calculateTrend(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let firstHalf = values.prefix(values.count / 2)
        let secondHalf = values.suffix(values.count / 2)
        
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        return secondAvg - firstAvg
    }
    
    /// Calculate data stability (inverse of variability)
    private func calculateStability(_ values: [Double]) -> Double {
        let variability = calculateVariability(values)
        return 1.0 - min(variability, 1.0)
    }
    
    /// Calculate coefficient of variation
    private func calculateVariability(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        
        return stdDev / mean
    }
    
    /// Calculate regularity of respiratory patterns
    private func calculateRegularity(_ rates: [Double]) -> Double {
        guard rates.count > 2 else { return 0 }
        
        var intervals: [Double] = []
        for i in 1..<rates.count {
            intervals.append(abs(rates[i] - rates[i-1]))
        }
        
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - avgInterval, 2) }.reduce(0, +) / Double(intervals.count)
        
        // Lower variance means higher regularity
        return 1.0 - min(sqrt(variance) / avgInterval, 1.0)
    }
    
    /// Detect periodic movements indicating position changes
    private func detectPeriodicMovements(_ data: [MovementData]) -> Int {
        var movementCount = 0
        var previousHighActivity = false
        
        for movement in data {
            let isHighActivity = movement.activityLevel >= 3
            
            // Count transitions from low to high activity
            if isHighActivity && !previousHighActivity {
                movementCount += 1
            }
            
            previousHighActivity = isHighActivity
        }
        
        return movementCount
    }
    
    /// Calculates confidence score for stage classification
    private func calculateConfidence(for epoch: SleepEpoch) -> Double {
        // Enhanced confidence calculation based on data quality and consistency
        let hrConfidence = epoch.heartRateData.reduce(0.0) { $0 + $1.confidence } / Double(epoch.heartRateData.count)
        let respConfidence = epoch.respiratoryData.reduce(0.0) { $0 + $1.confidence } / Double(epoch.respiratoryData.count)
        
        // Factor in data completeness
        let dataCompleteness = min(
            Double(epoch.heartRateData.count) / 30.0, // Expected ~30 readings per epoch
            Double(epoch.movementData.count) / 60.0,  // Expected ~60 readings per epoch
            Double(epoch.respiratoryData.count) / 15.0 // Expected ~15 readings per epoch
        )
        
        let baseConfidence = (hrConfidence + respConfidence) / 2.0
        return baseConfidence * dataCompleteness
    }
}

// MARK: - Supporting Data Structures

/// Represents a time window of sleep data for analysis
struct SleepEpoch {
    let startTime: Date
    let endTime: Date
    let heartRateData: [HeartRateData]
    let movementData: [MovementData]
    let respiratoryData: [RespiratoryData]
}

/// Comprehensive heart rate metrics for stage analysis
struct HeartRateMetrics {
    let average: Double
    let hrv: Double        // Heart Rate Variability
    let trend: Double      // Increasing/decreasing trend
    let stability: Double  // Consistency of readings
}

/// Movement analysis metrics
struct MovementMetrics {
    let avgMagnitude: Double
    let avgActivity: Double
    let variability: Double
    let periodicMovements: Int  // Count of position changes
}

/// Respiratory pattern metrics
struct RespiratoryMetrics {
    let avgRate: Double
    let avgOxygen: Double
    let variability: Double
    let regularity: Double  // Consistency of breathing pattern
}
