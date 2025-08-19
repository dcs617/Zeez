import Foundation
import CoreData
import os.log

/// Manages personalized sleep analysis parameters based on user's historical data
/// Provides adaptive thresholds and customized ranges that improve accuracy over time
final class PersonalizationManager {
    static let shared = PersonalizationManager()
    
    private let persistenceController: PersistenceController
    private let minimumSessionsForPersonalization = 7 // Need at least a week of data
    private let optimalSessionsForPersonalization = 30 // 30 days for stable baselines
    
    // MARK: - Initialization
    
    private init() {
        self.persistenceController = PersistenceController.shared
    }
    
    // MARK: - Personalized Cycle Analysis
    
    /// Calculate user's personalized sleep cycle length based on historical data
    func calculatePersonalizedCycleLength(for userId: UUID? = nil) async throws -> TimeInterval {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform {
            let sessions = try self.fetchRecentSessions(userId: userId, context: context)
            
            guard sessions.count >= self.minimumSessionsForPersonalization else {
                ZeezLogger.sleepTracking.info("Insufficient data for personalized cycle length, using standard 90 minutes")
                return AppConstants.SleepCycle.standardLength
            }
            
            var cycleDurations: [TimeInterval] = []
            
            for session in sessions {
                let cycles = self.extractCyclesFromSession(session)
                cycleDurations.append(contentsOf: cycles.map { $0.duration })
            }
            
            guard !cycleDurations.isEmpty else {
                return AppConstants.SleepCycle.standardLength
            }
            
            // Calculate personalized cycle length using median to reduce outlier impact
            let sortedDurations = cycleDurations.sorted()
            let personalizedLength = sortedDurations.median() ?? AppConstants.SleepCycle.standardLength
            
            // Validate the personalized length is within reasonable bounds
            let minLength: TimeInterval = 70 * 60 // 70 minutes
            let maxLength: TimeInterval = 110 * 60 // 110 minutes
            
            let clampedLength = max(minLength, min(maxLength, personalizedLength))
            
            ZeezLogger.sleepTracking.info("Calculated personalized cycle length: \(clampedLength / 60) minutes (from \(sessions.count) sessions)")
            
            return clampedLength
        }
    }
    
    /// Get personalized heart rate ranges based on user's historical data
    func getPersonalizedHeartRateRange(for userId: UUID? = nil) async throws -> ClosedRange<Double> {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform {
            let sessions = try self.fetchRecentSessions(userId: userId, context: context)
            
            guard sessions.count >= self.minimumSessionsForPersonalization else {
                ZeezLogger.sleepTracking.info("Using default heart rate range")
                return AppConstants.HealthMetrics.HeartRate.minimumSleep...AppConstants.HealthMetrics.HeartRate.maximumSleep
            }
            
            var heartRates: [Double] = []
            
            for session in sessions {
                if let heartRateData = session.heartRateData?.allObjects as? [HeartRateData] {
                    heartRates.append(contentsOf: heartRateData.map { $0.value })
                }
            }
            
            guard heartRates.count >= 50 else { // Need sufficient readings
                return AppConstants.HealthMetrics.HeartRate.minimumSleep...AppConstants.HealthMetrics.HeartRate.maximumSleep
            }
            
            let sortedRates = heartRates.sorted()
            
            // Use 10th and 90th percentiles to establish personalized range
            let tenthPercentile = sortedRates.percentile(10) ?? AppConstants.HealthMetrics.HeartRate.minimumSleep
            let ninetiethPercentile = sortedRates.percentile(90) ?? AppConstants.HealthMetrics.HeartRate.maximumSleep
            
            // Ensure reasonable bounds
            let personalizedMin = max(35.0, tenthPercentile) // Never below 35 BPM
            let personalizedMax = min(90.0, ninetiethPercentile) // Never above 90 BPM
            
            ZeezLogger.sleepTracking.info("Personalized heart rate range: \(personalizedMin)-\(personalizedMax) BPM")
            
            return personalizedMin...personalizedMax
        }
    }
    
    /// Get personalized environmental preference ranges
    func getPersonalizedEnvironmentalRanges(for userId: UUID? = nil) async throws -> PersonalizedEnvironmentalRanges {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform(schedule: .immediate) {
            let sessions = try self.fetchRecentSessions(userId: userId, context: context)
            
            guard sessions.count >= self.minimumSessionsForPersonalization else {
                ZeezLogger.sleepTracking.info("Using default environmental ranges")
                return PersonalizedEnvironmentalRanges.defaultRanges
            }
            
            var temperatures: [Double] = []
            var noiseLevels: [Double] = []
            var lightLevels: [Double] = []
            var qualityScores: [Double] = []
            
            // Collect environmental data from high-quality sleep sessions only
            for session in sessions where session.qualityScore > 70 {
                if let environmentalData = session.environmentalReadings?.allObjects as? [EnvironmentalReading] {
                    for reading in environmentalData {
                        temperatures.append(reading.temperature)
                        noiseLevels.append(reading.noiseLevel)
                        lightLevels.append(reading.lightLevel)
                        qualityScores.append(session.qualityScore)
                    }
                }
            }
            
            guard !temperatures.isEmpty else {
                return PersonalizedEnvironmentalRanges.defaultRanges
            }
            
            return PersonalizedEnvironmentalRanges(
                optimalTemperature: temperatures.weightedAverage(weights: qualityScores) ?? 21.0,
                temperatureTolerance: max(1.0, temperatures.standardDeviation ?? 2.0),
                optimalNoiseLevel: noiseLevels.weightedAverage(weights: qualityScores) ?? 30.0,
                noiseTolerance: max(5.0, noiseLevels.standardDeviation ?? 10.0),
                optimalLightLevel: lightLevels.weightedAverage(weights: qualityScores) ?? 5.0,
                lightTolerance: max(2.0, lightLevels.standardDeviation ?? 5.0)
            )
        }
    }
    
    // MARK: - Adaptive Thresholds
    
    /// Calculate confidence score for analysis based on data quality and historical patterns
    func calculateConfidenceScore(
        for session: SleepSession,
        userId: UUID? = nil
    ) async throws -> PersonalizationConfidence {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform {
            let historicalSessions = try self.fetchRecentSessions(userId: userId, context: context)
            
            var confidenceFactors: [String: Double] = [:]
            
            // Data completeness factor
            confidenceFactors["dataCompleteness"] = self.calculateDataCompletenessScore(for: session)
            
            // Historical consistency factor
            confidenceFactors["historicalConsistency"] = self.calculateHistoricalConsistencyScore(
                session: session,
                historicalSessions: historicalSessions
            )
            
            // Sensor reliability factor
            confidenceFactors["sensorReliability"] = self.calculateSensorReliabilityScore(for: session)
            
            // Duration adequacy factor
            confidenceFactors["durationAdequacy"] = self.calculateDurationAdequacyScore(for: session)
            
            let overallConfidence = confidenceFactors.values.reduce(0, +) / Double(confidenceFactors.count)
            
            return PersonalizationConfidence(
                overallScore: overallConfidence,
                factors: confidenceFactors,
                dataMaturity: self.calculateDataMaturity(sessionCount: historicalSessions.count)
            )
        }
    }
    
    // MARK: - Baseline Calculations
    
    /// Calculate individual baseline metrics for comprehensive personalization
    func calculatePersonalizedBaselines(for userId: UUID? = nil) async throws -> PersonalizedBaselines {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform {
            let sessions = try self.fetchRecentSessions(userId: userId, context: context)
            
            guard sessions.count >= self.minimumSessionsForPersonalization else {
                ZeezLogger.sleepTracking.info("Insufficient data for personalized baselines")
                return PersonalizedBaselines.defaultBaselines
            }
            
            // Calculate sleep duration baseline
            let durations = sessions.compactMap { session -> TimeInterval? in
                guard let start = session.startTime, let end = session.endTime else { return nil }
                return end.timeIntervalSince(start)
            }
            
            let avgDuration = durations.average ?? AppConstants.Sleep.targetDuration
            let durationVariability = durations.standardDeviation ?? 3600 // 1 hour default
            
            // Calculate bedtime consistency
            let bedtimes = sessions.compactMap { $0.startTime }
            let bedtimeConsistency = self.calculateBedtimeConsistency(bedtimes)
            
            // Calculate wake time consistency
            let wakeTimes = sessions.compactMap { $0.endTime }
            let wakeTimeConsistency = self.calculateWakeTimeConsistency(wakeTimes)
            
            return PersonalizedBaselines(
                averageSleepDuration: avgDuration,
                sleepDurationVariability: durationVariability,
                bedtimeConsistency: bedtimeConsistency,
                wakeTimeConsistency: wakeTimeConsistency,
                sessionCount: sessions.count,
                lastUpdated: Date()
            )
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func fetchRecentSessions(
        userId: UUID? = nil,
        context: NSManagedObjectContext,
        days: Int = 30
    ) throws -> [SleepSession] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "startTime >= %@", cutoffDate as NSDate)
        ]
        
        if let userId = userId {
            predicates.append(NSPredicate(format: "userId == %@", userId as CVarArg))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        
        return try context.fetch(request)
    }
    
    private func extractCyclesFromSession(_ session: SleepSession) -> [(duration: TimeInterval, quality: Double)] {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage] else { return [] }
        
        let sortedStages = stages.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
        var cycles: [(duration: TimeInterval, quality: Double)] = []
        var currentCycleDuration: TimeInterval = 0
        var currentCycleStages: [String] = []
        
        for stage in sortedStages {
            guard let stageType = stage.stageType else { continue }
            
            currentCycleDuration += stage.duration
            currentCycleStages.append(stageType)
            
            // Detect end of cycle (simplified logic)
            if stageType == "LIGHT" && currentCycleStages.contains("DEEP") && currentCycleStages.contains("REM") {
                let quality = calculateCycleQuality(stages: currentCycleStages)
                cycles.append((duration: currentCycleDuration, quality: quality))
                currentCycleDuration = 0
                currentCycleStages = []
            }
        }
        
        return cycles
    }
    
    private func calculateCycleQuality(stages: [String]) -> Double {
        let hasDeep = stages.contains("DEEP")
        let hasREM = stages.contains("REM")
        let hasLight = stages.contains("LIGHT")
        
        var quality = 0.0
        if hasLight { quality += 30 }
        if hasDeep { quality += 40 }
        if hasREM { quality += 30 }
        
        return quality
    }
    
    private func calculateDataCompletenessScore(for session: SleepSession) -> Double {
        var completenessScore = 0.0
        let maxScore = 4.0
        
        // Check heart rate data availability
        if let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
           !heartRateData.isEmpty {
            completenessScore += 1.0
        }
        
        // Check movement data availability
        if let movementData = session.movementData?.allObjects as? [MovementData],
           !movementData.isEmpty {
            completenessScore += 1.0
        }
        
        // Check environmental data availability
        if let environmentalData = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
           !environmentalData.isEmpty {
            completenessScore += 1.0
        }
        
        // Check sleep stages data
        if let sleepStages = session.sleepStages?.allObjects as? [SleepStage],
           !sleepStages.isEmpty {
            completenessScore += 1.0
        }
        
        return (completenessScore / maxScore) * 100
    }
    
    private func calculateHistoricalConsistencyScore(
        session: SleepSession,
        historicalSessions: [SleepSession]
    ) -> Double {
        guard historicalSessions.count > 3 else { return 50.0 } // Neutral score for insufficient data
        
        guard let sessionStart = session.startTime,
              let sessionEnd = session.endTime else { return 0.0 }
        
        let sessionDuration = sessionEnd.timeIntervalSince(sessionStart)
        let sessionBedtime = Calendar.current.component(.hour, from: sessionStart)
        
        let historicalDurations = historicalSessions.compactMap { session -> TimeInterval? in
            guard let start = session.startTime, let end = session.endTime else { return nil }
            return end.timeIntervalSince(start)
        }
        
        let historicalBedtimes = historicalSessions.compactMap { session -> Int? in
            guard let start = session.startTime else { return nil }
            return Calendar.current.component(.hour, from: start)
        }
        
        let avgDuration = historicalDurations.average ?? sessionDuration
        let avgBedtime = Double(historicalBedtimes.reduce(0, +)) / Double(historicalBedtimes.count)
        
        let durationDeviation = abs(sessionDuration - avgDuration) / 3600 // Hours
        let bedtimeDeviation = abs(Double(sessionBedtime) - avgBedtime)
        
        // Score decreases with deviation from historical patterns
        let durationScore = max(0, 100 - (durationDeviation * 25)) // Penalty for hour deviation
        let bedtimeScore = max(0, 100 - (bedtimeDeviation * 20)) // Penalty for hour deviation
        
        return (durationScore + bedtimeScore) / 2
    }
    
    private func calculateSensorReliabilityScore(for session: SleepSession) -> Double {
        var reliabilityScore = 0.0
        var sensorCount = 0
        
        // Heart rate sensor reliability
        if let heartRateData = session.heartRateData?.allObjects as? [HeartRateData] {
            sensorCount += 1
            let validReadings = heartRateData.filter { reading in
                reading.value >= 30 && reading.value <= 120 // Reasonable heart rate range
            }.count
            
            let reliability = Double(validReadings) / Double(max(1, heartRateData.count))
            reliabilityScore += reliability * 100
        }
        
        // Movement sensor reliability  
        if let movementData = session.movementData?.allObjects as? [MovementData] {
            sensorCount += 1
            let validReadings = movementData.filter { reading in
                reading.activityLevel >= 0 && reading.activityLevel <= 10 // Valid activity range
            }.count
            
            let reliability = Double(validReadings) / Double(max(1, movementData.count))
            reliabilityScore += reliability * 100
        }
        
        return sensorCount > 0 ? reliabilityScore / Double(sensorCount) : 50.0
    }
    
    private func calculateDurationAdequacyScore(for session: SleepSession) -> Double {
        guard let start = session.startTime, let end = session.endTime else { return 0.0 }
        
        let duration = end.timeIntervalSince(start)
        let targetDuration = AppConstants.Sleep.targetDuration
        
        // Optimal score for 7-9 hours
        if duration >= 7 * 3600 && duration <= 9 * 3600 {
            return 100.0
        }
        
        // Reduced score for shorter or longer durations
        let hoursFromTarget = abs(duration - targetDuration) / 3600
        return max(0, 100 - (hoursFromTarget * 15))
    }
    
    private func calculateDataMaturity(sessionCount: Int) -> DataMaturity {
        switch sessionCount {
        case 0..<7:
            return .insufficient
        case 7..<21:
            return .developing
        case 21..<60:
            return .adequate
        default:
            return .mature
        }
    }
    
    private func calculateBedtimeConsistency(_ bedtimes: [Date]) -> Double {
        guard bedtimes.count > 1 else { return 100.0 }
        
        let hours = bedtimes.map { Calendar.current.component(.hour, from: $0) }
        let avgHour = Double(hours.reduce(0, +)) / Double(hours.count)
        
        let deviations = hours.map { abs(Double($0) - avgHour) }
        let avgDeviation = deviations.reduce(0, +) / Double(deviations.count)
        
        return max(0, 100 - (avgDeviation * 20)) // 20 points penalty per hour deviation
    }
    
    private func calculateWakeTimeConsistency(_ wakeTimes: [Date]) -> Double {
        guard wakeTimes.count > 1 else { return 100.0 }
        
        let hours = wakeTimes.map { Calendar.current.component(.hour, from: $0) }
        let avgHour = Double(hours.reduce(0, +)) / Double(hours.count)
        
        let deviations = hours.map { abs(Double($0) - avgHour) }
        let avgDeviation = deviations.reduce(0, +) / Double(deviations.count)
        
        return max(0, 100 - (avgDeviation * 20)) // 20 points penalty per hour deviation
    }
}

// MARK: - Supporting Data Types

struct PersonalizedEnvironmentalRanges {
    let optimalTemperature: Double
    let temperatureTolerance: Double
    let optimalNoiseLevel: Double
    let noiseTolerance: Double
    let optimalLightLevel: Double
    let lightTolerance: Double
    
    static let defaultRanges = PersonalizedEnvironmentalRanges(
        optimalTemperature: 21.0,
        temperatureTolerance: 2.0,
        optimalNoiseLevel: 30.0,
        noiseTolerance: 10.0,
        optimalLightLevel: 5.0,
        lightTolerance: 5.0
    )
}

struct PersonalizationConfidence {
    let overallScore: Double
    let factors: [String: Double]
    let dataMaturity: DataMaturity
}

struct PersonalizedBaselines {
    let averageSleepDuration: TimeInterval
    let sleepDurationVariability: TimeInterval
    let bedtimeConsistency: Double
    let wakeTimeConsistency: Double
    let sessionCount: Int
    let lastUpdated: Date
    
    static let defaultBaselines = PersonalizedBaselines(
        averageSleepDuration: AppConstants.Sleep.targetDuration,
        sleepDurationVariability: 3600, // 1 hour
        bedtimeConsistency: 70.0,
        wakeTimeConsistency: 70.0,
        sessionCount: 0,
        lastUpdated: Date()
    )
}

enum DataMaturity {
    case insufficient
    case developing
    case adequate
    case mature
    
    var description: String {
        switch self {
        case .insufficient: return "Insufficient data for personalization"
        case .developing: return "Basic personalization available"
        case .adequate: return "Good personalization accuracy"
        case .mature: return "Highly accurate personalization"
        }
    }
}
