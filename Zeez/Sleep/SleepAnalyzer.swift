import CoreData
import Foundation
import os.log

final class SleepAnalyzer {
    static let shared = SleepAnalyzer()
    
    private let persistenceController: PersistenceController
    private let movementManager: MovementDataManager
    private let environmentalMonitor: EnvironmentalMonitor
    
    // Specialized analyzers
    private let stageAnalyzer: SleepStageAnalyzer
    private let qualityAnalyzer: SleepQualityAnalyzer
    private let cycleAnalyzer: SleepCycleAnalyzer?
    
    private init() {
        self.persistenceController = .shared
        self.movementManager = .shared
        self.environmentalMonitor = .shared
        
        let context = persistenceController.container.viewContext
        self.stageAnalyzer = SleepStageAnalyzer(context: context)
        self.qualityAnalyzer = SleepQualityAnalyzer(context: context, session: SleepSession()) // Will be set properly
        self.cycleAnalyzer = nil // Will be created per session
    }
    
    // MARK: - Sleep Analysis
    
    func analyzeSleepSession(_ session: SleepSession) async throws {
        guard let startTime = session.startTime,
              let endTime = session.endTime else {
            throw NSError(domain: "SleepAnalyzer", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid session times"])
        }
        
        let context = persistenceController.container.newBackgroundContext()
        
        // Get the session in this context
        guard let sessionInContext = await context.perform({
            return context.object(with: session.objectID) as? SleepSession
        }) else {
            throw NSError(domain: "SleepAnalyzer", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Could not get session in background context"])
        }
        
        // Calculate session duration and validate timing
        let sessionDuration = endTime.timeIntervalSince(startTime)
        let sessionHours = sessionDuration / 3600
        
        ZeezLogger.sleepTracking.info("Starting comprehensive analysis for session \(sessionInContext.id?.uuidString ?? "unknown")")
        ZeezLogger.sleepTracking.info("Session duration: \(String(format: "%.1f", sessionHours)) hours (\(startTime.formatted()) to \(endTime.formatted()))")
        
        // Validate session duration is reasonable (between 30 minutes and 16 hours)
        guard sessionDuration >= 1800 && sessionDuration <= 57600 else {
            ZeezLogger.sleepTracking.error("Invalid session duration: \(sessionHours) hours. Skipping analysis.")
            throw NSError(domain: "SleepAnalyzer", code: -3,
                         userInfo: [NSLocalizedDescriptionKey: "Session duration is unrealistic: \(String(format: "%.1f", sessionHours)) hours"])
        }
        
        // Step 1: Sleep Stage Analysis
        ZeezLogger.sleepTracking.debug("Performing sleep stage analysis...")
        let contextualStageAnalyzer = SleepStageAnalyzer(context: context)
        let sleepStages = try await contextualStageAnalyzer.analyzeSleepStages(for: sessionInContext)
        
        ZeezLogger.sleepTracking.info("Detected \(sleepStages.count) sleep stages")
        
        // Step 2: Sleep Quality Analysis  
        ZeezLogger.sleepTracking.debug("Performing sleep quality analysis...")
        let contextualQualityAnalyzer = SleepQualityAnalyzer(context: context, session: sessionInContext)
        let qualityScore = try await contextualQualityAnalyzer.analyzeSleepQuality()
        
        ZeezLogger.sleepTracking.info("Calculated quality score: \(qualityScore.overallScore)")
        
        // Step 3: Sleep Cycle Analysis
        ZeezLogger.sleepTracking.debug("Performing sleep cycle analysis...")
        let cycleAnalyzer = SleepCycleAnalyzer(session: sessionInContext, context: context)
        let cycleAnalysis = await cycleAnalyzer.analyzeCycles()
        
        ZeezLogger.sleepTracking.info("Found \(cycleAnalysis.cycleCount) sleep cycles with \(cycleAnalysis.completedCycles) complete cycles")
        
        // Step 4: Update session with consolidated results and save in context
        try await context.perform {
            sessionInContext.qualityScore = qualityScore.overallScore
            sessionInContext.completedCycles = Int16(cycleAnalysis.completedCycles)
            sessionInContext.cycleConsistency = cycleAnalysis.consistency
            
            try context.save()
        }
        
        // Step 5: Generate insights and recommendations
        try await self.generateSessionInsights(for: sessionInContext, 
                                             qualityScore: qualityScore,
                                             cycleAnalysis: cycleAnalysis,
                                             startTime: startTime,
                                             endTime: endTime,
                                             sessionDuration: sessionDuration,
                                             in: context)
        
        // Step 6: Update daily metrics with timing information
        try await context.perform {
            try self.updateDailyMetrics(for: sessionInContext, sessionDuration: sessionDuration, in: context)
        }
        
        ZeezLogger.sleepTracking.info("Comprehensive analysis completed successfully")
    }
    
    // MARK: - Session Insights Generation
    
    /// Generate comprehensive insights and recommendations for a sleep session
    private func generateSessionInsights(
        for session: SleepSession,
        qualityScore: SleepQualityScore,
        cycleAnalysis: CycleAnalysis,
        startTime: Date,
        endTime: Date,
        sessionDuration: TimeInterval,
        in context: NSManagedObjectContext
    ) async throws {
        // Generate personalized recommendations based on the analysis
        let recommendationSystem = SleepRecommendationSystem.shared
        let sessionRecommendations = try await generateSessionRecommendations(
            session: session,
            qualityScore: qualityScore, 
            cycleAnalysis: cycleAnalysis,
            startTime: startTime,
            endTime: endTime,
            sessionDuration: sessionDuration,
            using: recommendationSystem
        )
        
        // Create session summary note
        let summaryNote = SleepNote(context: context)
        summaryNote.id = UUID()
        summaryNote.timestamp = Date()
        summaryNote.category = "session_summary"
        summaryNote.content = createSessionSummary(
            qualityScore: qualityScore, 
            cycleAnalysis: cycleAnalysis,
            startTime: startTime,
            endTime: endTime,
            sessionDuration: sessionDuration
        )
        
        // Add insights from cycle analysis
        for insight in cycleAnalysis.insights {
            let insightNote = SleepNote(context: context)
            insightNote.id = UUID()
            insightNote.timestamp = Date()
            insightNote.category = "cycle_insight"
            insightNote.content = "\(insight.title): \(insight.message)"
            session.addToNotes(insightNote)
        }
        
        // Add personalized recommendations
        for (index, recommendation) in sessionRecommendations.enumerated() {
            let recommendationNote = SleepNote(context: context)
            recommendationNote.id = UUID()
            recommendationNote.timestamp = Date()
            recommendationNote.category = "recommendation"
            recommendationNote.title = "Recommendation \(index + 1)"
            recommendationNote.content = recommendation
            session.addToNotes(recommendationNote)
        }
        
        session.addToNotes(summaryNote)
        
        ZeezLogger.sleepTracking.debug("Generated \(cycleAnalysis.insights.count + sessionRecommendations.count + 1) insights and recommendations for session")
    }
    
    /// Create a comprehensive session summary
    private func createSessionSummary(
        qualityScore: SleepQualityScore, 
        cycleAnalysis: CycleAnalysis,
        startTime: Date,
        endTime: Date,
        sessionDuration: TimeInterval
    ) -> String {
        let sessionHours = sessionDuration / 3600
        let sessionMinutes = Int((sessionDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        return """
        Sleep Session Analysis Summary
        
        Session Timing:
        • Bedtime: \(startTime.formatted(date: .abbreviated, time: .shortened))
        • Wake Time: \(endTime.formatted(date: .abbreviated, time: .shortened))
        • Duration: \(String(format: "%.0f", sessionHours))h \(sessionMinutes)m
        
        Overall Quality Score: \(String(format: "%.1f", qualityScore.overallScore))%
        
        Component Scores:
        • Heart Rate: \(String(format: "%.1f", qualityScore.heartRateScore))%
        • Movement: \(String(format: "%.1f", qualityScore.movementScore))%
        • Environmental: \(String(format: "%.1f", qualityScore.environmentalScore))%
        • Respiratory: \(String(format: "%.1f", qualityScore.respiratoryScore))%
        • Sleep Cycles: \(String(format: "%.1f", qualityScore.sleepCycleScore))%
        
        Sleep Cycle Analysis:
        • Total Cycles: \(cycleAnalysis.cycleCount)
        • Completed Cycles: \(cycleAnalysis.completedCycles)
        • Cycle Consistency: \(String(format: "%.1f", cycleAnalysis.consistency))%
        • Average Cycle Duration: \(String(format: "%.1f", cycleAnalysis.averageDuration / 60)) minutes
        
        Generated on \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))
        """
    }
    
    // MARK: - Legacy Sleep Stage Detection (Deprecated)
    // TODO: Remove once all code paths use SleepStageAnalyzer
    
    private func detectSleepStages(_ session: SleepSession, in context: NSManagedObjectContext) throws -> [SleepStage] {
        guard let startTime = session.startTime,
              let endTime = session.endTime else { return [] }
        
        let movements = try movementManager.getMovementData(for: session)
        
        var stages: [SleepStage] = []
        
        // Group movement data into 30-minute intervals
        let intervalDuration: TimeInterval = AppConstants.SleepCycle.stageAnalysisInterval
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
    
    // MARK: - Legacy Score Calculations (Deprecated)
    // TODO: Remove these methods as they're now handled by SleepQualityAnalyzer
    
    @available(*, deprecated, message: "Use SleepQualityAnalyzer instead")
    private func calculateMovementScore(_ movements: [MovementData]) -> Double {
        // Legacy implementation - kept for compatibility during transition
        let totalMovements = Double(movements.count)
        guard totalMovements > 0 else { return 100 }
        
        let restlessMovements = Double(movements.filter { $0.activityLevel >= 3 }.count)
        let restlessRatio = restlessMovements / totalMovements
        
        return (1 - restlessRatio) * 100
    }
    
    @available(*, deprecated, message: "Use SleepQualityAnalyzer instead")
    private func calculateEnvironmentalScore(_ readings: [EnvironmentalReading]) -> Double {
        // Legacy implementation - kept for compatibility during transition
        guard !readings.isEmpty else { return 100 }
        
        let scores: [Double] = readings.map { reading in
            var score = 100.0
            
            if reading.noiseLevel > 50 {
                score -= (reading.noiseLevel - 50) / 2
            }
            
            if reading.lightLevel > 20 {
                score -= (reading.lightLevel - 20) / 2
            }
            
            return max(0, score)
        }
        
        return scores.reduce(0, +) / Double(scores.count)
    }
    
    @available(*, deprecated, message: "Use SleepQualityAnalyzer instead")
    private func calculateSleepCycleScore(duration: TimeInterval) -> Double {
        // Legacy implementation - kept for compatibility during transition
        let hours = duration / 3600
        
        if hours >= 7 && hours <= 9 {
            return 100
        } else if hours < 7 {
            return (hours / 7) * 100
        } else {
            return max(0, 100 - ((hours - 9) * 10))
        }
    }
    
    @available(*, deprecated, message: "Use SleepQualityAnalyzer instead")
    private func calculateOverallScore(
        movementScore: Double,
        environmentalScore: Double,
        sleepCycleScore: Double
    ) -> Double {
        // Legacy implementation - kept for compatibility during transition
        let weightedScores = [
            movementScore * 0.4,
            environmentalScore * 0.3,
            sleepCycleScore * 0.3
        ]
        
        return weightedScores.reduce(0, +)
    }
    
    // MARK: - Metrics Updates
    
    private func updateDailyMetrics(for session: SleepSession, sessionDuration: TimeInterval, in context: NSManagedObjectContext) throws {
        guard let startTime = session.startTime else { return }
        
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
        
        // Log session duration for tracking
        ZeezLogger.sleepTracking.debug("Adding session duration \(String(format: "%.1f", sessionDuration / 3600))h to daily metrics for \(startOfDay.formatted(date: .abbreviated, time: .omitted))")
        
        // Update metrics
        try updateTotalSleepTime(for: dailyMetrics)
        try updateAverageHeartRate(for: dailyMetrics)
        try updateSleepDebt(for: dailyMetrics)
        
        // Note: context.save() is called by the parent method
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
    
    /// Generate session-specific recommendations based on sleep analysis
    private func generateSessionRecommendations(
        session: SleepSession,
        qualityScore: SleepQualityScore,
        cycleAnalysis: CycleAnalysis,
        startTime: Date,
        endTime: Date,
        sessionDuration: TimeInterval,
        using recommendationSystem: SleepRecommendationSystem
    ) async throws -> [String] {
        var recommendations: [String] = []
        
        // Duration-based recommendations
        let sessionHours = sessionDuration / 3600
        if sessionHours < 6 {
            recommendations.append("Your sleep duration was \(String(format: "%.1f", sessionHours)) hours. Consider aiming for 7-9 hours for optimal recovery.")
        } else if sessionHours > 10 {
            recommendations.append("You slept for \(String(format: "%.1f", sessionHours)) hours. Excessively long sleep may indicate sleep debt or underlying issues.")
        }
        
        // Bedtime analysis
        let calendar = Calendar.current
        let bedtimeHour = calendar.component(.hour, from: startTime)
        if bedtimeHour >= 0 && bedtimeHour <= 5 {
            recommendations.append("You went to bed at \(startTime.formatted(date: .omitted, time: .shortened)). Consider an earlier bedtime for better sleep quality.")
        } else if bedtimeHour >= 23 || bedtimeHour <= 1 {
            recommendations.append("Late bedtime detected (\(startTime.formatted(date: .omitted, time: .shortened))). Try to establish a consistent earlier bedtime routine.")
        }
        
        // Wake time analysis
        let wakeHour = calendar.component(.hour, from: endTime)
        if wakeHour >= 10 {
            recommendations.append("You woke up at \(endTime.formatted(date: .omitted, time: .shortened)). Consider gradually shifting to an earlier wake time for better circadian rhythm alignment.")
        }
        
        // Quality-based recommendations
        if qualityScore.overallScore < 70 {
            recommendations.append("Your sleep quality score was \(String(format: "%.0f", qualityScore.overallScore))%. Consider improving your sleep environment for better quality rest.")
        }
        
        if qualityScore.heartRateScore < 60 {
            recommendations.append("Your heart rate patterns suggest you may need more relaxation before bed")
        }
        
        if qualityScore.movementScore < 60 {
            recommendations.append("High movement during sleep may indicate discomfort or stress")
        }
        
        if qualityScore.environmentalScore < 60 {
            recommendations.append("Consider optimizing your bedroom temperature and lighting")
        }
        
        // Cycle-based recommendations
        if cycleAnalysis.completedCycles < 3 {
            recommendations.append("You completed \(cycleAnalysis.completedCycles) sleep cycles. Try to get more sleep to complete 4-6 cycles for optimal recovery.")
        }
        
        if cycleAnalysis.consistency < 0.7 {
            recommendations.append("Work on maintaining a consistent sleep schedule")
        }
        
        return recommendations
    }
}
