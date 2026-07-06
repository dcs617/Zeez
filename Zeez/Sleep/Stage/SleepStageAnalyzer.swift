import CoreData
import os.log

/// Research-based sleep stage analyzer using movement patterns, heart rate variability,
/// and sleep cycle timing to classify sleep stages accurately
class SleepStageAnalyzer {
    private let context: NSManagedObjectContext
    
    // Sleep cycle constants based on research
    private let avgCycleDuration: TimeInterval = 90 * 60 // 90 minutes
    private let firstREMLatency: TimeInterval = 75 * 60  // 75 minutes (first REM typically delayed)
    private let minStageDuration: TimeInterval = 10 * 60 // 10 minutes minimum
    private let sleepOnsetWindow: TimeInterval = 15 * 60 // 15 minutes for sleep onset detection
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Public Entry Points

    /// Synchronous entry point for use inside a `context.perform` block.
    ///
    /// Pre-sorted movements and heart rates must be provided by the caller (SleepAnalyzer
    /// already sorts them while checking the evidence threshold). Returns an empty array
    /// when no stages can be computed rather than throwing.
    func analyzeSleepStagesSync(
        for session: SleepSession,
        movements: [MovementData],
        heartRates: [HeartRateData]
    ) throws -> [SleepStage] {
        guard let startTime = session.startTime,
              let endTime = session.endTime else {
            throw NSError(domain: "SleepStageAnalyzer", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid session times"])
        }

        ZeezLogger.sleepTracking.info("Analyzing stages for session \(startTime) – \(endTime)")

        let baselineHR = calculateRestingHeartRate(heartRates: heartRates)
        let sleepOnsetTime = detectSleepOnset(movements: movements, heartRates: heartRates,
                                             sessionStart: startTime, baselineHR: baselineHR)
        let rawStages = createRawStages(startTime: startTime, endTime: endTime,
                                       sleepOnsetTime: sleepOnsetTime,
                                       movements: movements, heartRates: heartRates,
                                       baselineHR: baselineHR)
        let cycleAdjustedStages = applyREMCycles(stages: rawStages, sleepOnsetTime: sleepOnsetTime)
        let smoothedStages = smoothStageTransitions(rawStages: cycleAdjustedStages)
        let stages = try createSleepStageEntitiesSync(smoothedStages, session: session)
        logStageStatistics(stages)
        return stages
    }

    /// Async entry point retained for any call sites that still use it directly.
    func analyzeSleepStages(for session: SleepSession) async throws -> [SleepStage] {
        guard let startTime = session.startTime,
              let endTime = session.endTime else {
            throw NSError(domain: "SleepStageAnalyzer", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid session times"])
        }

        ZeezLogger.sleepTracking.info("Analyzing sleep stages for session from \(startTime) to \(endTime)")

        let movements = (session.movementData?.allObjects as? [MovementData] ?? [])
            .sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        let heartRates = (session.heartRateData?.allObjects as? [HeartRateData] ?? [])
            .sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }

        return try analyzeSleepStagesSync(for: session, movements: movements, heartRates: heartRates)
    }
    
    // MARK: - Sleep Onset Detection
    
    private func detectSleepOnset(movements: [MovementData], heartRates: [HeartRateData],
                                sessionStart: Date, baselineHR: Double) -> Date {
        let windowDuration: TimeInterval = 15 * 60 // 15-minute windows
        var currentTime = sessionStart
        let maxSearchTime = sessionStart.addingTimeInterval(2 * 3600) // Search up to 2 hours
        
        while currentTime < maxSearchTime {
            let windowEnd = currentTime.addingTimeInterval(windowDuration)
            
            // Get data for this window
            let windowMovements = movements.filter { movement in
                guard let timestamp = movement.timestamp else { return false }
                return timestamp >= currentTime && timestamp < windowEnd
            }
            
            let windowHeartRates = heartRates.filter { hr in
                guard let timestamp = hr.timestamp else { return false }
                return timestamp >= currentTime && timestamp < windowEnd
            }
            
            // Check for sleep onset indicators
            let avgMovement = calculateAverageMovement(movements: windowMovements)
            let avgHeartRate = calculateAverageHeartRate(heartRates: windowHeartRates)
            let hrDrop = baselineHR - avgHeartRate
            
            // Sleep onset criteria:
            // 1. Low movement (< 1.0 on 0-5 scale)
            // 2. Heart rate drop of at least 5 BPM
            // 3. Sustained for at least 15 minutes
            if avgMovement < 1.0 && hrDrop >= 5.0 {
                ZeezLogger.sleepTracking.debug("Sleep onset criteria met - Movement: \(avgMovement), HR drop: \(hrDrop)")
                return currentTime
            }
            
            currentTime = currentTime.addingTimeInterval(5 * 60) // Check every 5 minutes
        }
        
        // Fallback: assume sleep onset 30 minutes after session start
        return sessionStart.addingTimeInterval(30 * 60)
    }
    
    // MARK: - Heart Rate Analysis
    
    private func calculateRestingHeartRate(heartRates: [HeartRateData]) -> Double {
        guard !heartRates.isEmpty else { return 65.0 } // Default if no data
        
        // Use lowest 20% of readings as baseline resting HR
        let sortedRates = heartRates.map { $0.value }.sorted()
        let bottomPercentileCount = max(1, Int(Double(sortedRates.count) * 0.2))
        let lowestRates = Array(sortedRates.prefix(bottomPercentileCount))
        
        return lowestRates.reduce(0.0, +) / Double(lowestRates.count)
    }
    
    private func analyzeHeartRatePattern(heartRates: [HeartRateData]) -> HeartRatePattern {
        guard !heartRates.isEmpty else {
            return HeartRatePattern(average: 65.0, variability: 0.0, trend: .stable, stability: 1.0)
        }
        
        let values = heartRates.map { $0.value }
        let average = values.reduce(0.0, +) / Double(values.count)
        
        // Calculate RMSSD (variability)
        var sumSquaredDiffs = 0.0
        for i in 1..<values.count {
            let diff = values[i] - values[i-1]
            sumSquaredDiffs += diff * diff
        }
        let rmssd = values.count > 1 ? sqrt(sumSquaredDiffs / Double(values.count - 1)) : 0.0
        
        // Determine trend
        let firstHalf = Array(values.prefix(values.count / 2))
        let secondHalf = Array(values.suffix(values.count / 2))
        let firstAvg = firstHalf.reduce(0.0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0.0, +) / Double(secondHalf.count)
        let trend: HRTrend = secondAvg > firstAvg + 2 ? .increasing :
                            secondAvg < firstAvg - 2 ? .decreasing : .stable
        
        // Calculate stability (inverse of coefficient of variation)
        let standardDeviation = sqrt(calculateVariance(values: values))
        let coefficientOfVariation = average > 0 ? standardDeviation / average : 0
        let stability = max(0.0, 1.0 - coefficientOfVariation)
        
        return HeartRatePattern(average: average, variability: rmssd, trend: trend, stability: stability)
    }
    
    // MARK: - Raw Stage Creation
    
    private func createRawStages(startTime: Date, endTime: Date, sleepOnsetTime: Date,
                               movements: [MovementData], heartRates: [HeartRateData],
                               baselineHR: Double) -> [(startTime: Date, endTime: Date, stage: SleepStageType, confidence: Double)] {
        var stages: [(Date, Date, SleepStageType, Double)] = []
        let epochDuration: TimeInterval = 5 * 60 // 5-minute epochs for precision
        var currentTime = startTime
        
        while currentTime < endTime {
            let epochEnd = min(currentTime.addingTimeInterval(epochDuration), endTime)
            
            // Filter data for current epoch
            let epochMovements = movements.filter { movement in
                guard let timestamp = movement.timestamp else { return false }
                return timestamp >= currentTime && timestamp < epochEnd
            }
            
            let epochHeartRates = heartRates.filter { hr in
                guard let timestamp = hr.timestamp else { return false }
                return timestamp >= currentTime && timestamp < epochEnd
            }
            
            // Determine stage based on sleep onset timing
            let stage: SleepStageType
            let confidence: Double
            
            if currentTime < sleepOnsetTime {
                // Before sleep onset - classify as awake
                stage = .awake
                confidence = 90.0
            } else {
                // After sleep onset - use physiological classification
                let result = classifyPhysiologicalStage(movements: epochMovements,
                                                      heartRates: epochHeartRates,
                                                      baselineHR: baselineHR,
                                                      timeFromSleepOnset: currentTime.timeIntervalSince(sleepOnsetTime))
                stage = result.stage
                confidence = result.confidence
            }
            
            stages.append((currentTime, epochEnd, stage, confidence))
            currentTime = epochEnd
        }
        
        return stages
    }
    
    private func classifyPhysiologicalStage(movements: [MovementData], heartRates: [HeartRateData],
                                          baselineHR: Double, timeFromSleepOnset: TimeInterval)
    -> (stage: SleepStageType, confidence: Double) {
        
        let avgMovement = calculateAverageMovement(movements: movements)
        let hrPattern = analyzeHeartRatePattern(heartRates: heartRates)
        
        // Calculate confidence based on data quality
        let dataConfidence = calculateDataConfidence(movements: movements, heartRates: heartRates)
        
        // Sleep stage classification using research-based thresholds
        // Movement scale: 0-5 (from activityLevel in MovementData)
        let sleepHR = baselineHR * 0.85 // Sleep HR typically 15% lower than resting
        
        switch (avgMovement, hrPattern.average, hrPattern.variability) {
        case let (m, hr, var_hr) where m <= 0.5 && hr <= sleepHR + 5 && var_hr < 3.0:
            // Deep sleep: very low movement, low stable HR, low variability
            return (.deepSleep, dataConfidence * 0.9)
            
        case let (m, hr, var_hr) where m <= 1.5 && hr <= sleepHR + 10 && var_hr < 5.0:
            // Light sleep: low movement, moderate HR, some variability
            return (.lightSleep, dataConfidence * 0.8)
            
        case let (m, hr, _) where m >= 2.0 || hr > sleepHR + 15:
            // Awake: higher movement or elevated HR
            return (.awake, dataConfidence * 0.85)
            
        default:
            // Default to light sleep for ambiguous cases
            return (.lightSleep, dataConfidence * 0.6)
        }
    }
    
    // MARK: - REM Cycle Application
    
    private func applyREMCycles(stages: [(startTime: Date, endTime: Date, stage: SleepStageType, confidence: Double)],
                              sleepOnsetTime: Date) -> [(startTime: Date, endTime: Date, stage: SleepStageType, confidence: Double)] {
        var adjustedStages = stages
        let totalSleepDuration = stages.last?.endTime.timeIntervalSince(sleepOnsetTime) ?? 0
        
        // Calculate expected REM periods based on sleep cycles
        let remPeriods = calculateREMPeriods(sleepOnsetTime: sleepOnsetTime, totalDuration: totalSleepDuration)
        
        ZeezLogger.sleepTracking.debug("Calculated \(remPeriods.count) REM periods")
        
        // Apply REM periods to appropriate stages
        for remPeriod in remPeriods {
            for i in 0..<adjustedStages.count {
                let stage = adjustedStages[i]
                
                // Check if this epoch overlaps with REM period and isn't awake
                if stage.stage != .awake &&
                   stage.startTime < remPeriod.end &&
                   stage.endTime > remPeriod.start {
                    
                    // Convert to REM if conditions are met
                    let avgMovement = stage.stage == .deepSleep ? 0.3 : 1.0 // Estimate based on current stage
                    if avgMovement <= 1.0 { // REM has minimal movement
                        adjustedStages[i] = (stage.startTime, stage.endTime, .rem, stage.confidence * 0.9)
                    }
                }
            }
        }
        
        return adjustedStages
    }
    
    private func calculateREMPeriods(sleepOnsetTime: Date, totalDuration: TimeInterval) -> [(start: Date, end: Date)] {
        var remPeriods: [(Date, Date)] = []
        let cycleCount = Int(totalDuration / avgCycleDuration)
        
        for cycle in 0..<cycleCount {
            let cycleStart = sleepOnsetTime.addingTimeInterval(Double(cycle) * avgCycleDuration)
            
            // REM timing within cycle (typically last 20-30 minutes of cycle)
            let remStart = cycleStart.addingTimeInterval(avgCycleDuration * 0.75) // Start at 75% of cycle
            let remDuration = min(20 * 60, avgCycleDuration * 0.25) // 20 minutes or 25% of cycle
            let remEnd = remStart.addingTimeInterval(remDuration)
            
            // First REM period is typically shorter and later
            if cycle == 0 {
                let delayedStart = remStart.addingTimeInterval(10 * 60) // Delay first REM
                remPeriods.append((delayedStart, min(remEnd, delayedStart.addingTimeInterval(10 * 60))))
            } else {
                // Later REM periods get progressively longer
                let extendedDuration = remDuration + Double(cycle) * 5 * 60 // +5 min per cycle
                remPeriods.append((remStart, remStart.addingTimeInterval(extendedDuration)))
            }
        }
        
        return remPeriods
    }
    
    // MARK: - Stage Transition Smoothing
    
    private func smoothStageTransitions(rawStages: [(startTime: Date, endTime: Date, stage: SleepStageType, confidence: Double)])
    -> [(startTime: Date, endTime: Date, stage: SleepStageType, confidence: Double)] {
        
        guard rawStages.count > 2 else { return rawStages }
        
        var smoothedStages = rawStages
        
        // Apply minimum duration constraint and smooth isolated stages
        for i in 1..<smoothedStages.count - 1 {
            let previous = smoothedStages[i-1]
            let current = smoothedStages[i]
            let next = smoothedStages[i+1]
            
            // Smooth isolated stages (single epoch surrounded by different stages)
            if previous.stage == next.stage && current.stage != previous.stage {
                // Replace isolated stage with surrounding stage
                smoothedStages[i] = (current.startTime, current.endTime, previous.stage, current.confidence * 0.8)
            }
            
            // Prevent unrealistic transitions (e.g., Deep Sleep → Awake directly)
            if previous.stage == .deepSleep && current.stage == .awake {
                // Insert light sleep as transition
                smoothedStages[i] = (current.startTime, current.endTime, .lightSleep, current.confidence * 0.7)
            }
        }
        
        return smoothedStages
    }
    
    // MARK: - Core Data Entity Creation

    private func createSleepStageEntitiesSync(
        _ stages: [(startTime: Date, endTime: Date, stage: SleepStageType, confidence: Double)],
        session: SleepSession
    ) throws -> [SleepStage] {
        var entities: [SleepStage] = []
        for stageData in stages {
            let stage = SleepStage(context: context)
            stage.id = UUID()
            stage.startTime = stageData.startTime
            stage.endTime = stageData.endTime
            stage.stageType = stageData.stage.rawValue
            stage.duration = stageData.endTime.timeIntervalSince(stageData.startTime)
            stage.confidence = stageData.confidence
            stage.session = session
            entities.append(stage)
        }
        try context.save()
        return entities
    }

    private func createSleepStageEntities(
        _ stages: [(startTime: Date, endTime: Date, stage: SleepStageType, confidence: Double)],
        session: SleepSession
    ) async throws -> [SleepStage] {
        try createSleepStageEntitiesSync(stages, session: session)
    }
    
    // MARK: - Helper Methods
    
    private func calculateAverageMovement(movements: [MovementData]) -> Double {
        guard !movements.isEmpty else { return 0.0 }
        
        let totalActivity = movements.reduce(0) { $0 + Int($1.activityLevel) }
        return Double(totalActivity) / Double(movements.count)
    }
    
    private func calculateAverageHeartRate(heartRates: [HeartRateData]) -> Double {
        guard !heartRates.isEmpty else { return 65.0 } // Default
        
        return heartRates.reduce(0.0) { $0 + $1.value } / Double(heartRates.count)
    }
    
    private func calculateDataConfidence(movements: [MovementData], heartRates: [HeartRateData]) -> Double {
        // Base confidence on data availability and consistency
        let expectedReadings = 60.0 // Expected readings per epoch
        let actualReadings = Double(movements.count + heartRates.count)
        let dataAvailability = min(1.0, actualReadings / expectedReadings)
        
        // Movement consistency (lower variance = higher confidence)
        let movementVariance = calculateVariance(values: movements.map { Double($0.activityLevel) })
        let movementConsistency = max(0.0, 1.0 - (movementVariance / 5.0)) // Scale to 0-5 range
        
        return min(100.0, (dataAvailability * 0.7 + movementConsistency * 0.3) * 100)
    }
    
    private func calculateVariance(values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        
        let mean = values.reduce(0.0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return squaredDiffs.reduce(0.0, +) / Double(values.count)
    }
    
    private func logStageStatistics(_ stages: [SleepStage]) {
        let totalDuration = stages.reduce(0.0) { $0 + $1.duration }
        let deepCount = stages.filter { SleepStageType.deepSleep.matches($0.stageType) }.count
        let lightCount = stages.filter { SleepStageType.lightSleep.matches($0.stageType) }.count
        let remCount = stages.filter { SleepStageType.rem.matches($0.stageType) }.count
        let awakeCount = stages.filter { SleepStageType.awake.matches($0.stageType) }.count
        
        let deepPercent = totalDuration > 0 ? (Double(deepCount) / Double(stages.count)) * 100 : 0
        let lightPercent = totalDuration > 0 ? (Double(lightCount) / Double(stages.count)) * 100 : 0
        let remPercent = totalDuration > 0 ? (Double(remCount) / Double(stages.count)) * 100 : 0
        let awakePercent = totalDuration > 0 ? (Double(awakeCount) / Double(stages.count)) * 100 : 0
        
        ZeezLogger.sleepTracking.info("Stage distribution - Deep: \(deepPercent)%, Light: \(lightPercent)%, REM: \(remPercent)%, Awake: \(awakePercent)%")
        ZeezLogger.sleepTracking.info("Total stages created: \(stages.count), Total duration: \(totalDuration/3600) hours")
    }
}

// MARK: - Supporting Types

struct HeartRatePattern {
    let average: Double
    let variability: Double
    let trend: HRTrend
    let stability: Double
}

enum HRTrend {
    case increasing
    case decreasing
    case stable
}