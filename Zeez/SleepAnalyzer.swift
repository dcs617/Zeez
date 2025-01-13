import CoreData
import Foundation

final class SleepAnalyzer {
    static let shared = SleepAnalyzer()
    
    private let persistenceController: PersistenceController
    private let movementManager: MovementDataManager
    private let environmentalMonitor: EnvironmentalMonitor
    
    private init() {
        self.persistenceController = .shared
        self.movementManager = .shared
        self.environmentalMonitor = .shared
    }
    
    // MARK: - Sleep Analysis
    
    func analyzeSleepSession(_ session: SleepSession) async throws {
        guard let startTime = session.startTime,
              let endTime = session.endTime else {
            throw NSError(domain: "SleepAnalyzer", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid session times"])
        }
        
        let context = persistenceController.container.viewContext
        
        // Calculate basic metrics
        let duration = DateHelper.calculateSleepDuration(startTime: startTime, endTime: endTime)
        let sleepStages = try detectSleepStages(session)
        let movementData = try movementManager.getMovementData(for: session)
        let environmentalReadings = try environmentalMonitor.getEnvironmentalReadings(for: session)
        
        // Create quality score
        let qualityScore = SleepQualityScore(context: context)
        qualityScore.id = UUID()
        qualityScore.timestamp = Date()
        qualityScore.session = session
        qualityScore.calculationVersion = "1.0"
        
        // Calculate component scores
        qualityScore.movementScore = calculateMovementScore(movementData)
        qualityScore.environmentalScore = calculateEnvironmentalScore(environmentalReadings)
        qualityScore.sleepCycleScore = calculateSleepCycleScore(duration: duration)
        
        // Calculate overall score
        qualityScore.overallScore = calculateOverallScore(
            movementScore: qualityScore.movementScore,
            environmentalScore: qualityScore.environmentalScore,
            sleepCycleScore: qualityScore.sleepCycleScore
        )
        
        // Update session with final score
        session.qualityScore = qualityScore.overallScore
        
        try context.save()
        
        // Create or update daily metrics
        try updateDailyMetrics(for: session)
    }
    
    // MARK: - Sleep Stage Detection
    
    private func detectSleepStages(_ session: SleepSession) throws -> [SleepStage] {
        guard let startTime = session.startTime,
              let endTime = session.endTime else { return [] }
        
        let context = persistenceController.container.viewContext
        let movements = try movementManager.getMovementData(for: session)
        
        var currentStageStart = startTime
        var stages: [SleepStage] = []
        
        // Group movement data into 30-minute intervals
        let intervalDuration: TimeInterval = 30 * 60
        var currentTime = startTime
        
        while currentTime < endTime {
            let intervalEnd = min(currentTime.addingTimeInterval(intervalDuration), endTime)
            
            let intervalMovements = movements.filter { movement in
                guard let timestamp = movement.timestamp else { return false }
                return timestamp >= currentTime && timestamp < intervalEnd
            }
            
            let averageActivity = Double(intervalMovements.reduce(0) { $0 + Int($1.activityLevel) }) / 
                                Double(max(intervalMovements.count, 1))
            
            // Determine sleep stage based on movement
            let stageType = determineSleepStage(averageActivity: averageActivity)
            
            let stage = SleepStage(context: context)
            stage.id = UUID()
            stage.startTime = currentTime
            stage.endTime = intervalEnd
            stage.stageType = stageType
            stage.duration = intervalEnd.timeIntervalSince(currentTime)
            stage.confidence = calculateStageConfidence(averageActivity: averageActivity)
            stage.session = session
            
            stages.append(stage)
            currentTime = intervalEnd
        }
        
        return stages
    }
    
    private func determineSleepStage(averageActivity: Double) -> String {
        switch averageActivity {
        case 0...0.5:   return "deep"
        case 0.5...1.5: return "light"
        case 1.5...2.5: return "rem"
        default:        return "awake"
        }
    }
    
    private func calculateStageConfidence(averageActivity: Double) -> Double {
        // Basic confidence calculation based on activity stability
        // Can be enhanced with more sophisticated algorithms
        return max(0, min(1 - (averageActivity / 5), 1)) * 100
    }
    
    // MARK: - Score Calculations
    
    private func calculateMovementScore(_ movements: [MovementData]) -> Double {
        let totalMovements = Double(movements.count)
        guard totalMovements > 0 else { return 100 }
        
        let restlessMovements = Double(movements.filter { $0.activityLevel >= 3 }.count)
        let restlessRatio = restlessMovements / totalMovements
        
        return (1 - restlessRatio) * 100
    }
    
    private func calculateEnvironmentalScore(_ readings: [EnvironmentalReading]) -> Double {
        guard !readings.isEmpty else { return 100 }
        
        let scores: [Double] = readings.map { reading in
            var score = 100.0
            
            // Penalize for non-optimal conditions
            if reading.noiseLevel > 50 { // Above 50dB
                score -= (reading.noiseLevel - 50) / 2
            }
            
            if reading.lightLevel > 20 { // Above 20 lux
                score -= (reading.lightLevel - 20) / 2
            }
            
            return max(0, score)
        }
        
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    private func calculateSleepCycleScore(duration: TimeInterval) -> Double {
        let hours = duration / 3600
        
        // Optimal sleep duration is between 7-9 hours
        if hours >= 7 && hours <= 9 {
            return 100
        } else if hours < 7 {
            return (hours / 7) * 100
        } else {
            return max(0, 100 - ((hours - 9) * 10))
        }
    }
    
    private func calculateOverallScore(
        movementScore: Double,
        environmentalScore: Double,
        sleepCycleScore: Double
    ) -> Double {
        // Weighted average of component scores
        let weightedScores = [
            movementScore * 0.4,      // 40% weight
            environmentalScore * 0.3,  // 30% weight
            sleepCycleScore * 0.3     // 30% weight
        ]
        
        return weightedScores.reduce(0, +)
    }
    
    // MARK: - Metrics Updates
    
    private func updateDailyMetrics(for session: SleepSession) throws {
        guard let startTime = session.startTime else { return }
        
        let context = persistenceController.container.viewContext
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startTime)
        
        // Fetch or create daily metrics
        let request: NSFetchRequest<DailyMetrics> = DailyMetrics.fetchRequest()
        request.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)
        
        let dailyMetrics = try context.fetch(request).first ?? DailyMetrics(context: context)
        
        if dailyMetrics.id == nil {
            dailyMetrics.id = UUID()
            dailyMetrics.date = startOfDay
            dailyMetrics.createdAt = Date()
        }
        
        dailyMetrics.modifiedAt = Date()
        dailyMetrics.addToSessions(session)
        
        // Update metrics
        try updateTotalSleepTime(for: dailyMetrics)
        try updateAverageHeartRate(for: dailyMetrics)
        try updateSleepDebt(for: dailyMetrics)
        
        try context.save()
    }
    
    private func updateTotalSleepTime(for metrics: DailyMetrics) throws {
        guard let sessions = metrics.sessions?.allObjects as? [SleepSession] else { return }
        
        let totalTime = sessions.reduce(0.0) { total, session in
            guard let startTime = session.startTime,
                  let endTime = session.endTime else { return total }
            return total + endTime.timeIntervalSince(startTime)
        }
        
        metrics.totalSleepTime = totalTime / 3600 // Convert to hours
    }
    
    private func updateAverageHeartRate(for metrics: DailyMetrics) throws {
        guard let sessions = metrics.sessions?.allObjects as? [SleepSession] else { return }
        
        var totalHeartRate = 0.0
        var readingCount = 0
        
        for session in sessions {
            guard let heartRateData = session.heartRateData?.allObjects as? [HeartRateData] else { continue }
            
            totalHeartRate += heartRateData.reduce(0.0) { $0 + $1.value }
            readingCount += heartRateData.count
        }
        
        metrics.averageHeartRate = readingCount > 0 ? totalHeartRate / Double(readingCount) : 0
    }
    
    private func updateSleepDebt(for metrics: DailyMetrics) throws {
        let context = persistenceController.container.viewContext
        let preferencesRequest: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        
        guard let preferences = try context.fetch(preferencesRequest).first,
              preferences.sleepGoalEnabled else { return }
        
        let targetSleep = preferences.targetSleepDuration
        metrics.sleepDebt = targetSleep - metrics.totalSleepTime
    }
}