import Foundation
import CoreData
import os.log

/// Advanced sleep pattern recognition and historical trend analysis
/// Provides insights into long-term sleep patterns and user-specific trends
final class HistoricalAnalyzer {
    private let persistenceController: PersistenceController
    private let personalizationManager: PersonalizationManager
    
    init() {
        self.persistenceController = PersistenceController.shared
        self.personalizationManager = PersonalizationManager.shared
    }
    
    // MARK: - Pattern Recognition
    
    /// Analyze sleep patterns over time to identify trends and consistencies
    func analyzeSleepPatterns(
        userId: UUID? = nil,
        days: Int = 30
    ) async throws -> SleepPatternAnalysis {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform {
            let sessions = try self.fetchSessionsForAnalysis(
                userId: userId,
                days: days,
                context: context
            )
            
            guard sessions.count >= 7 else {
                ZeezLogger.sleepTracking.info("Insufficient sessions for pattern analysis")
                return SleepPatternAnalysis.insufficientData
            }
            
            let weekdayPatterns = self.analyzeWeekdayPatterns(sessions)
            let seasonalTrends = self.analyzeSeasonalTrends(sessions)
            let qualityTrends = self.analyzeQualityTrends(sessions)
            let cycleTrends = self.analyzeCycleTrends(sessions)
            let environmentalCorrelations = try self.analyzeEnvironmentalCorrelations(sessions)
            
            return SleepPatternAnalysis(
                totalSessions: sessions.count,
                analysisRange: days,
                weekdayPatterns: weekdayPatterns,
                seasonalTrends: seasonalTrends,
                qualityTrends: qualityTrends,
                cycleTrends: cycleTrends,
                environmentalCorrelations: environmentalCorrelations,
                confidence: self.calculatePatternConfidence(sessions: sessions),
                generatedAt: Date()
            )
        }
    }
    
    /// Detect sleep consistency score based on historical patterns
    func calculateSleepConsistency(
        userId: UUID? = nil,
        days: Int = 14
    ) async throws -> SleepConsistencyScore {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform {
            let sessions = try self.fetchSessionsForAnalysis(
                userId: userId,
                days: days,
                context: context
            )
            
            guard sessions.count >= 5 else {
                return SleepConsistencyScore.insufficientData
            }
            
            let bedtimeConsistency = self.calculateBedtimeConsistency(sessions)
            let durationConsistency = self.calculateDurationConsistency(sessions)
            let qualityConsistency = self.calculateQualityConsistency(sessions)
            let cycleConsistency = self.calculateCycleConsistency(sessions)
            
            let overallScore = (bedtimeConsistency + durationConsistency + qualityConsistency + cycleConsistency) / 4.0
            
            return SleepConsistencyScore(
                overallScore: overallScore,
                bedtimeConsistency: bedtimeConsistency,
                durationConsistency: durationConsistency,
                qualityConsistency: qualityConsistency,
                cycleConsistency: cycleConsistency,
                sessionCount: sessions.count,
                recommendations: self.generateConsistencyRecommendations(
                    bedtime: bedtimeConsistency,
                    duration: durationConsistency,
                    quality: qualityConsistency,
                    cycle: cycleConsistency
                )
            )
        }
    }
    
    /// Predict optimal sleep parameters based on historical data
    func predictOptimalSleepParameters(
        userId: UUID? = nil
    ) async throws -> OptimalSleepParameters {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform {
            let sessions = try self.fetchSessionsForAnalysis(
                userId: userId,
                days: 60, // Use 2 months of data for prediction
                context: context
            )
            
            guard sessions.count >= 14 else {
                return OptimalSleepParameters.defaultParameters
            }
            
            // Analyze high-quality sleep sessions (>80% quality score)
            let highQualitySessions = sessions.filter { $0.qualityScore > 80 }
            
            guard !highQualitySessions.isEmpty else {
                return self.generateParametersFromAllSessions(sessions)
            }
            
            let optimalBedtime = self.calculateOptimalBedtime(highQualitySessions)
            let optimalDuration = self.calculateOptimalDuration(highQualitySessions)
            let optimalEnvironment = self.calculateOptimalEnvironment(highQualitySessions)
            let optimalCycleLength = self.calculateOptimalCycleLength(highQualitySessions)
            
            return OptimalSleepParameters(
                optimalBedtime: optimalBedtime,
                optimalWakeTime: optimalBedtime.addingTimeInterval(optimalDuration),
                optimalDuration: optimalDuration,
                optimalEnvironment: optimalEnvironment,
                optimalCycleLength: optimalCycleLength,
                confidence: self.calculatePredictionConfidence(
                    sessions: sessions,
                    highQualitySessions: highQualitySessions
                ),
                basedOnSessions: highQualitySessions.count
            )
        }
    }
    
    // MARK: - Trend Analysis
    
    /// Analyze sleep debt trends over time
    func analyzeSleepDebtTrends(
        userId: UUID? = nil,
        days: Int = 30
    ) async throws -> SleepDebtTrends {
        let context = persistenceController.container.newBackgroundContext()
        
        return try await context.perform {
            let sessions = try self.fetchSessionsForAnalysis(
                userId: userId,
                days: days,
                context: context
            )
            
            let targetDuration = AppConstants.Sleep.targetDuration
            var dailyDebts: [Date: TimeInterval] = [:]
            var runningDebt: TimeInterval = 0
            
            for session in sessions.sorted(by: { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }) {
                guard let start = session.startTime,
                      let end = session.endTime else { continue }
                
                let sessionDuration = end.timeIntervalSince(start)
                let dayDebt = targetDuration - sessionDuration
                runningDebt += dayDebt
                
                let day = Calendar.current.startOfDay(for: start)
                dailyDebts[day] = runningDebt
            }
            
            let weeklyAverages = self.calculateWeeklyDebtAverages(dailyDebts)
            let trendDirection = self.calculateDebtTrend(weeklyAverages)
            
            return SleepDebtTrends(
                dailyDebts: dailyDebts,
                weeklyAverages: weeklyAverages,
                currentDebt: runningDebt,
                trendDirection: trendDirection,
                projectedWeeklyDebt: self.projectWeeklyDebt(weeklyAverages),
                recommendations: self.generateDebtRecommendations(runningDebt, trendDirection)
            )
        }
    }
    
    // MARK: - Private Analysis Methods
    
    private func fetchSessionsForAnalysis(
        userId: UUID?,
        days: Int,
        context: NSManagedObjectContext
    ) throws -> [SleepSession] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "startTime >= %@", cutoffDate as NSDate),
            NSPredicate(format: "startTime != nil AND endTime != nil")
        ]
        
        if let userId = userId {
            predicates.append(NSPredicate(format: "userId == %@", userId as CVarArg))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
        
        return try context.fetch(request)
    }
    
    private func analyzeWeekdayPatterns(_ sessions: [SleepSession]) -> WeekdayPatterns {
        var weekdayData: [Int: [SleepSession]] = [:]
        
        for session in sessions {
            guard let startTime = session.startTime else { continue }
            let weekday = Calendar.current.component(.weekday, from: startTime)
            weekdayData[weekday, default: []].append(session)
        }
        
        var patterns: [Int: WeekdayPattern] = [:]
        
        for (weekday, sessions) in weekdayData {
            let avgDuration = sessions.compactMap { session -> TimeInterval? in
                guard let start = session.startTime, let end = session.endTime else { return nil }
                return end.timeIntervalSince(start)
            }.average ?? 0
            
            let avgQuality = sessions.map { $0.qualityScore }.average ?? 0
            let avgBedtime = self.calculateAverageBedtime(sessions)
            
            patterns[weekday] = WeekdayPattern(
                weekday: weekday,
                averageDuration: avgDuration,
                averageQuality: avgQuality,
                averageBedtime: avgBedtime,
                sessionCount: sessions.count
            )
        }
        
        return WeekdayPatterns(patterns: patterns)
    }
    
    private func analyzeSeasonalTrends(_ sessions: [SleepSession]) -> SeasonalTrends {
        // Group sessions by month
        var monthlyData: [Int: [SleepSession]] = [:]
        
        for session in sessions {
            guard let startTime = session.startTime else { continue }
            let month = Calendar.current.component(.month, from: startTime)
            monthlyData[month, default: []].append(session)
        }
        
        var trends: [Int: MonthlyTrend] = [:]
        
        for (month, sessions) in monthlyData {
            let avgDuration = sessions.compactMap { session -> TimeInterval? in
                guard let start = session.startTime, let end = session.endTime else { return nil }
                return end.timeIntervalSince(start)
            }.average ?? 0
            
            let avgQuality = sessions.map { $0.qualityScore }.average ?? 0
            
            trends[month] = MonthlyTrend(
                month: month,
                averageDuration: avgDuration,
                averageQuality: avgQuality,
                sessionCount: sessions.count
            )
        }
        
        return SeasonalTrends(monthlyTrends: trends)
    }
    
    private func analyzeQualityTrends(_ sessions: [SleepSession]) -> QualityTrends {
        let sortedSessions = sessions.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
        
        let qualityScores = sortedSessions.map { $0.qualityScore }
        let movingAverage = self.calculateMovingAverage(qualityScores, windowSize: 7)
        
        let trend = self.calculateTrendDirection(movingAverage)
        let volatility = qualityScores.standardDeviation ?? 0
        
        return QualityTrends(
            scores: qualityScores,
            movingAverage: movingAverage,
            trend: trend,
            volatility: volatility,
            averageScore: qualityScores.average ?? 0
        )
    }
    
    private func analyzeCycleTrends(_ sessions: [SleepSession]) -> CycleTrends {
        var cycleCounts: [Int] = []
        var cycleQualities: [Double] = []
        
        for session in sessions {
            // Calculate completed cycles from sleep stages using basic analysis
            if let stages = session.sleepStages?.allObjects as? [SleepStage] {
                let cycleMetrics = self.calculateBasicCycleMetrics(stages: stages)
                cycleCounts.append(cycleMetrics.completedCycles)
                cycleQualities.append(cycleMetrics.consistency)
            } else {
                cycleCounts.append(0)
                cycleQualities.append(0.0)
            }
        }
        
        return CycleTrends(
            averageCycleCount: cycleCounts.map(Double.init).average ?? 0,
            averageCycleQuality: cycleQualities.average ?? 0,
            cycleCountVariability: cycleCounts.map(Double.init).standardDeviation ?? 0,
            trend: self.calculateTrendDirection(cycleQualities)
        )
    }
    
    private func analyzeEnvironmentalCorrelations(_ sessions: [SleepSession]) throws -> EnvironmentalCorrelations {
        var temperatureQualityPairs: [(Double, Double)] = []
        var noiseQualityPairs: [(Double, Double)] = []
        var lightQualityPairs: [(Double, Double)] = []
        
        for session in sessions {
            guard let environmentalData = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
                  !environmentalData.isEmpty else { continue }
            
            let avgTemperature = environmentalData.map { $0.temperature }.average ?? 0
            let avgNoise = environmentalData.map { $0.noiseLevel }.average ?? 0
            let avgLight = environmentalData.map { $0.lightLevel }.average ?? 0
            
            temperatureQualityPairs.append((avgTemperature, session.qualityScore))
            noiseQualityPairs.append((avgNoise, session.qualityScore))
            lightQualityPairs.append((avgLight, session.qualityScore))
        }
        
        return EnvironmentalCorrelations(
            temperatureCorrelation: self.calculateCorrelation(temperatureQualityPairs),
            noiseCorrelation: self.calculateCorrelation(noiseQualityPairs),
            lightCorrelation: self.calculateCorrelation(lightQualityPairs),
            optimalTemperature: self.findOptimalEnvironmentalValue(temperatureQualityPairs),
            optimalNoiseLevel: self.findOptimalEnvironmentalValue(noiseQualityPairs),
            optimalLightLevel: self.findOptimalEnvironmentalValue(lightQualityPairs)
        )
    }
    
    private func calculateBedtimeConsistency(_ sessions: [SleepSession]) -> Double {
        let bedtimes = sessions.compactMap { $0.startTime }
        guard bedtimes.count > 1 else { return 100.0 }
        
        let bedtimeHours = bedtimes.map { Calendar.current.component(.hour, from: $0) }
        let avgBedtime = Double(bedtimeHours.reduce(0, +)) / Double(bedtimeHours.count)
        
        let deviations = bedtimeHours.map { abs(Double($0) - avgBedtime) }
        let avgDeviation = deviations.reduce(0, +) / Double(deviations.count)
        
        return max(0, 100 - (avgDeviation * 25)) // 25 points penalty per hour deviation
    }
    
    private func calculateDurationConsistency(_ sessions: [SleepSession]) -> Double {
        let durations = sessions.compactMap { session -> TimeInterval? in
            guard let start = session.startTime, let end = session.endTime else { return nil }
            return end.timeIntervalSince(start)
        }
        
        guard durations.count > 1 else { return 100.0 }
        
        let _ = durations.average ?? 0  // avgDuration - calculated for potential future use
        let standardDev = durations.standardDeviation ?? 0
        
        // Lower standard deviation = higher consistency
        let maxAcceptableDeviation: TimeInterval = 2 * 3600 // 2 hours
        let consistencyScore = max(0, 100 - ((standardDev / maxAcceptableDeviation) * 100))
        
        return consistencyScore
    }
    
    private func calculateQualityConsistency(_ sessions: [SleepSession]) -> Double {
        let qualities = sessions.map { $0.qualityScore }
        guard qualities.count > 1 else { return 100.0 }
        
        let standardDev = qualities.standardDeviation ?? 0
        
        // Lower standard deviation = higher consistency
        let maxAcceptableDeviation: Double = 20 // 20 points quality deviation
        return max(0, 100 - ((standardDev / maxAcceptableDeviation) * 100))
    }
    
    private func calculateCycleConsistency(_ sessions: [SleepSession]) -> Double {
        var cycleConsistencies: [Double] = []
        
        for session in sessions {
            if let stages = session.sleepStages?.allObjects as? [SleepStage] {
                let cycleMetrics = self.calculateBasicCycleMetrics(stages: stages)
                cycleConsistencies.append(cycleMetrics.consistency)
            }
        }
        
        guard !cycleConsistencies.isEmpty else { return 0.0 }
        
        return cycleConsistencies.average ?? 0
    }
    
    private func calculateOptimalBedtime(_ sessions: [SleepSession]) -> Date {
        let bedtimes = sessions.compactMap { $0.startTime }
        let bedtimeHours = bedtimes.map { Calendar.current.component(.hour, from: $0) }
        let avgHour = Double(bedtimeHours.reduce(0, +)) / Double(bedtimeHours.count)
        
        let calendar = Calendar.current
        let today = Date()
        
        return calendar.date(bySetting: .hour, value: Int(avgHour), of: today) ?? today
    }
    
    private func calculateOptimalDuration(_ sessions: [SleepSession]) -> TimeInterval {
        let durations = sessions.compactMap { session -> TimeInterval? in
            guard let start = session.startTime, let end = session.endTime else { return nil }
            return end.timeIntervalSince(start)
        }
        
        return durations.average ?? AppConstants.Sleep.targetDuration
    }
    
    private func calculateOptimalEnvironment(_ sessions: [SleepSession]) -> OptimalEnvironment {
        // Calculate averages from session data instead of using async personalization manager
        var temperatures: [Double] = []
        var noiseLevels: [Double] = []
        var lightLevels: [Double] = []
        
        for session in sessions {
            if let environmentalData = session.environmentalReadings?.allObjects as? [EnvironmentalReading] {
                temperatures.append(contentsOf: environmentalData.map { $0.temperature })
                noiseLevels.append(contentsOf: environmentalData.map { $0.noiseLevel })
                lightLevels.append(contentsOf: environmentalData.map { $0.lightLevel })
            }
        }
        
        return OptimalEnvironment(
            temperature: temperatures.average ?? 21.0, // Default comfortable temp
            noiseLevel: noiseLevels.average ?? 30.0,    // Default quiet level
            lightLevel: lightLevels.average ?? 5.0      // Default low light
        )
    }
    
    private func calculateOptimalCycleLength(_ sessions: [SleepSession]) -> TimeInterval {
        // Extract cycle durations from sessions
        var cycleDurations: [TimeInterval] = []
        
        for session in sessions {
            if let stages = session.sleepStages?.allObjects as? [SleepStage] {
                let cycleMetrics = self.calculateBasicCycleMetrics(stages: stages)
                cycleDurations.append(cycleMetrics.averageDuration)
            }
        }
        
        return cycleDurations.average ?? AppConstants.SleepCycle.standardLength
    }
    
    // MARK: - Helper Methods
    
    private func calculateBasicCycleMetrics(stages: [SleepStage]) -> (completedCycles: Int, consistency: Double, averageDuration: TimeInterval) {
        // Use standard cycle length for basic calculation
        let standardCycleLength = AppConstants.SleepCycle.standardLength
        
        // Sort stages by time
        let sortedStages = stages.sorted { 
            ($0.startTime ?? Date()) < ($1.startTime ?? Date())
        }
        
        guard !sortedStages.isEmpty else {
            return (completedCycles: 0, consistency: 0.0, averageDuration: standardCycleLength)
        }
        
        // Calculate total sleep time
        guard let firstStage = sortedStages.first, let lastStage = sortedStages.last,
              let startTime = firstStage.startTime, let endTime = lastStage.startTime else {
            return (completedCycles: 0, consistency: 0.0, averageDuration: standardCycleLength)
        }
        
        let totalSleepTime = endTime.timeIntervalSince(startTime) + lastStage.duration
        
        // Estimate completed cycles
        let completedCycles = Int(totalSleepTime / standardCycleLength)
        
        // Calculate consistency based on stage distribution
        let deepStages = sortedStages.filter { $0.stageType == "DEEP" }
        let remStages = sortedStages.filter { $0.stageType == "REM" }
        
        let deepPercent = deepStages.reduce(0) { $0 + $1.duration } / totalSleepTime * 100
        let remPercent = remStages.reduce(0) { $0 + $1.duration } / totalSleepTime * 100
        
        // Ideal percentages: Deep 15-20%, REM 20-25%
        let deepScore = max(0, 100 - abs(deepPercent - 17.5) * 4)
        let remScore = max(0, 100 - abs(remPercent - 22.5) * 4)
        let consistency = (deepScore + remScore) / 2
        
        let averageDuration = completedCycles > 0 ? totalSleepTime / Double(completedCycles) : standardCycleLength
        
        return (completedCycles: completedCycles, consistency: consistency, averageDuration: averageDuration)
    }
    
    private func calculateAverageBedtime(_ sessions: [SleepSession]) -> Date {
        let bedtimes = sessions.compactMap { $0.startTime }
        let hours = bedtimes.map { Calendar.current.component(.hour, from: $0) }
        let avgHour = Double(hours.reduce(0, +)) / Double(max(1, hours.count))
        
        let calendar = Calendar.current
        let today = Date()
        
        return calendar.date(bySetting: .hour, value: Int(avgHour), of: today) ?? today
    }
    
    private func calculateMovingAverage(_ values: [Double], windowSize: Int) -> [Double] {
        guard values.count >= windowSize else { return values }
        
        var movingAverages: [Double] = []
        
        for i in 0...(values.count - windowSize) {
            let window = Array(values[i..<(i + windowSize)])
            movingAverages.append(window.average ?? 0)
        }
        
        return movingAverages
    }
    
    private func calculateTrendDirection(_ values: [Double]) -> TrendDirection {
        guard values.count >= 3 else { return .stable }
        
        let firstThird = Array(values.prefix(values.count / 3))
        let lastThird = Array(values.suffix(values.count / 3))
        
        let firstAvg = firstThird.average ?? 0
        let lastAvg = lastThird.average ?? 0
        
        let change = lastAvg - firstAvg
        let changePercent = abs(change) / max(firstAvg, 1) * 100
        
        if changePercent > 5 {
            return change > 0 ? .improving : .declining
        } else {
            return .stable
        }
    }
    
    private func calculateCorrelation(_ pairs: [(Double, Double)]) -> Double {
        guard pairs.count > 2 else { return 0 }
        
        let x = pairs.map { $0.0 }
        let y = pairs.map { $0.1 }
        
        let avgX = x.average ?? 0
        let avgY = y.average ?? 0
        
        let numerator = zip(x, y).map { ($0 - avgX) * ($1 - avgY) }.reduce(0, +)
        let denomX = x.map { pow($0 - avgX, 2) }.reduce(0, +)
        let denomY = y.map { pow($0 - avgY, 2) }.reduce(0, +)
        
        let denominator = sqrt(denomX * denomY)
        
        return denominator > 0 ? numerator / denominator : 0
    }
    
    private func findOptimalEnvironmentalValue(_ pairs: [(Double, Double)]) -> Double {
        guard !pairs.isEmpty else { return 0 }
        
        // Find the environmental value that correlates with highest quality
        let sortedByQuality = pairs.sorted { $0.1 > $1.1 }
        let topQuartile = Array(sortedByQuality.prefix(max(1, pairs.count / 4)))
        
        return topQuartile.map { $0.0 }.average ?? 0
    }
    
    private func calculatePatternConfidence(sessions: [SleepSession]) -> Double {
        let sessionCount = sessions.count
        
        switch sessionCount {
        case 0..<7: return 30.0
        case 7..<14: return 50.0
        case 14..<30: return 75.0
        default: return 90.0
        }
    }
    
    private func calculatePredictionConfidence(sessions: [SleepSession], highQualitySessions: [SleepSession]) -> Double {
        let totalSessions = sessions.count
        let qualitySessions = highQualitySessions.count
        
        let dataQuality = Double(qualitySessions) / Double(totalSessions) * 100
        let sampleSize = min(Double(totalSessions) / 30.0, 1.0) * 100 // Max confidence at 30+ sessions
        
        return (dataQuality + sampleSize) / 2.0
    }
    
    private func generateParametersFromAllSessions(_ sessions: [SleepSession]) -> OptimalSleepParameters {
        let avgDuration = sessions.compactMap { session -> TimeInterval? in
            guard let start = session.startTime, let end = session.endTime else { return nil }
            return end.timeIntervalSince(start)
        }.average ?? AppConstants.Sleep.targetDuration
        
        let avgBedtime = calculateOptimalBedtime(sessions)
        
        return OptimalSleepParameters(
            optimalBedtime: avgBedtime,
            optimalWakeTime: avgBedtime.addingTimeInterval(avgDuration),
            optimalDuration: avgDuration,
            optimalEnvironment: OptimalEnvironment.defaultEnvironment,
            optimalCycleLength: AppConstants.SleepCycle.standardLength,
            confidence: 40.0, // Lower confidence for all sessions
            basedOnSessions: sessions.count
        )
    }
    
    private func generateConsistencyRecommendations(
        bedtime: Double,
        duration: Double,
        quality: Double,
        cycle: Double
    ) -> [String] {
        var recommendations: [String] = []
        
        if bedtime < 70 {
            recommendations.append("Try to maintain a more consistent bedtime routine")
        }
        
        if duration < 70 {
            recommendations.append("Aim for more consistent sleep duration each night")
        }
        
        if quality < 70 {
            recommendations.append("Focus on factors that improve sleep quality consistency")
        }
        
        if cycle < 70 {
            recommendations.append("Consider environmental factors that may affect your sleep cycles")
        }
        
        return recommendations.isEmpty ? ["Your sleep patterns show good consistency"] : recommendations
    }
    
    private func calculateWeeklyDebtAverages(_ dailyDebts: [Date: TimeInterval]) -> [TimeInterval] {
        let sortedEntries = dailyDebts.sorted { $0.key < $1.key }
        var weeklyAverages: [TimeInterval] = []
        
        for i in stride(from: 0, to: sortedEntries.count, by: 7) {
            let weekData = Array(sortedEntries[i..<min(i + 7, sortedEntries.count)])
            let weekAvg = weekData.map { $0.value }.average ?? 0
            weeklyAverages.append(weekAvg)
        }
        
        return weeklyAverages
    }
    
    private func calculateDebtTrend(_ weeklyAverages: [TimeInterval]) -> TrendDirection {
        return calculateTrendDirection(weeklyAverages)
    }
    
    private func projectWeeklyDebt(_ weeklyAverages: [TimeInterval]) -> TimeInterval {
        guard weeklyAverages.count >= 2 else { return 0 }
        
        let recentAverage = weeklyAverages.suffix(2).average ?? 0
        return recentAverage
    }
    
    private func generateDebtRecommendations(_ currentDebt: TimeInterval, _ trend: TrendDirection) -> [String] {
        var recommendations: [String] = []
        
        let debtHours = currentDebt / 3600
        
        if debtHours > 10 {
            recommendations.append("Significant sleep debt detected. Consider gradually increasing sleep duration")
        }
        
        if trend == .declining {
            recommendations.append("Sleep debt is increasing. Focus on consistent bedtime and duration")
        } else if trend == .improving {
            recommendations.append("Good progress on reducing sleep debt. Maintain current habits")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Data Structures

struct SleepPatternAnalysis {
    let totalSessions: Int
    let analysisRange: Int
    let weekdayPatterns: WeekdayPatterns
    let seasonalTrends: SeasonalTrends
    let qualityTrends: QualityTrends
    let cycleTrends: CycleTrends
    let environmentalCorrelations: EnvironmentalCorrelations
    let confidence: Double
    let generatedAt: Date
    
    static let insufficientData = SleepPatternAnalysis(
        totalSessions: 0,
        analysisRange: 0,
        weekdayPatterns: WeekdayPatterns(patterns: [:]),
        seasonalTrends: SeasonalTrends(monthlyTrends: [:]),
        qualityTrends: QualityTrends(scores: [], movingAverage: [], trend: .stable, volatility: 0, averageScore: 0),
        cycleTrends: CycleTrends(averageCycleCount: 0, averageCycleQuality: 0, cycleCountVariability: 0, trend: .stable),
        environmentalCorrelations: EnvironmentalCorrelations(temperatureCorrelation: 0, noiseCorrelation: 0, lightCorrelation: 0, optimalTemperature: 21, optimalNoiseLevel: 30, optimalLightLevel: 5),
        confidence: 0,
        generatedAt: Date()
    )
}

struct WeekdayPatterns {
    let patterns: [Int: WeekdayPattern]
}

struct WeekdayPattern {
    let weekday: Int
    let averageDuration: TimeInterval
    let averageQuality: Double
    let averageBedtime: Date
    let sessionCount: Int
}

struct SeasonalTrends {
    let monthlyTrends: [Int: MonthlyTrend]
}

struct MonthlyTrend {
    let month: Int
    let averageDuration: TimeInterval
    let averageQuality: Double
    let sessionCount: Int
}

struct QualityTrends {
    let scores: [Double]
    let movingAverage: [Double]
    let trend: TrendDirection
    let volatility: Double
    let averageScore: Double
}

struct CycleTrends {
    let averageCycleCount: Double
    let averageCycleQuality: Double
    let cycleCountVariability: Double
    let trend: TrendDirection
}

struct EnvironmentalCorrelations {
    let temperatureCorrelation: Double
    let noiseCorrelation: Double
    let lightCorrelation: Double
    let optimalTemperature: Double
    let optimalNoiseLevel: Double
    let optimalLightLevel: Double
}

struct SleepConsistencyScore {
    let overallScore: Double
    let bedtimeConsistency: Double
    let durationConsistency: Double
    let qualityConsistency: Double
    let cycleConsistency: Double
    let sessionCount: Int
    let recommendations: [String]
    
    static let insufficientData = SleepConsistencyScore(
        overallScore: 0,
        bedtimeConsistency: 0,
        durationConsistency: 0,
        qualityConsistency: 0,
        cycleConsistency: 0,
        sessionCount: 0,
        recommendations: ["Insufficient data for consistency analysis"]
    )
}

struct OptimalSleepParameters {
    let optimalBedtime: Date
    let optimalWakeTime: Date
    let optimalDuration: TimeInterval
    let optimalEnvironment: OptimalEnvironment
    let optimalCycleLength: TimeInterval
    let confidence: Double
    let basedOnSessions: Int
    
    static let defaultParameters = OptimalSleepParameters(
        optimalBedtime: Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date(),
        optimalWakeTime: Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date()) ?? Date(),
        optimalDuration: AppConstants.Sleep.targetDuration,
        optimalEnvironment: OptimalEnvironment.defaultEnvironment,
        optimalCycleLength: AppConstants.SleepCycle.standardLength,
        confidence: 30.0,
        basedOnSessions: 0
    )
}

struct OptimalEnvironment {
    let temperature: Double
    let noiseLevel: Double
    let lightLevel: Double
    
    static let defaultEnvironment = OptimalEnvironment(
        temperature: 21.0,
        noiseLevel: 30.0,
        lightLevel: 5.0
    )
}

struct SleepDebtTrends {
    let dailyDebts: [Date: TimeInterval]
    let weeklyAverages: [TimeInterval]
    let currentDebt: TimeInterval
    let trendDirection: TrendDirection
    let projectedWeeklyDebt: TimeInterval
    let recommendations: [String]
}

enum TrendDirection {
    case improving
    case declining
    case stable
}