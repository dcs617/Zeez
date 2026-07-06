import Foundation
import CoreData
import os.log

/// System for generating personalized sleep recommendations based on user data and sleep science
final class SleepRecommendationSystem {
    static let shared = SleepRecommendationSystem()
    private let persistenceController: PersistenceController
    
    private init() {
        self.persistenceController = .shared
    }
    
    deinit {
        // No explicit cleanup needed for persistenceController reference
        // but provide deinit for consistency and future extensibility
    }
    
    /// Reset singleton state for testing
    func reset() {
        // No mutable state to reset in this singleton
        // but provide method for consistency
    }
    
    /// User age group categories for sleep recommendations
    enum AgeGroup {
        case youngAdult      // 18-25
        case adult          // 26-64
        case olderAdult     // 65+
        
        var recommendedSleepRange: ClosedRange<Double> {
            switch self {
            case .youngAdult: return 7.0...9.0
            case .adult: return 7.0...9.0
            case .olderAdult: return 7.0...8.0
            }
        }
    }
    
    /// Activity level impacts sleep needs
    enum ActivityLevel {
        case sedentary
        case moderate
        case active
        case athletic
        
        var sleepAdjustment: Double {
            switch self {
            case .sedentary: return 0.0
            case .moderate: return 0.5
            case .active: return 1.0
            case .athletic: return 1.5
            }
        }
    }
    
    /// Generate personalized sleep recommendations
    func generateRecommendations(
        ageGroup: AgeGroup,
        activityLevel: ActivityLevel
    ) async throws -> SleepRecommendations {
        let sleepData = try await fetchRecentSleepData()
        
        // Calculate base recommendations from age group
        let baseRange = ageGroup.recommendedSleepRange
        
        // Adjust for activity level
        let adjustment = activityLevel.sleepAdjustment
        let adjustedRange = (baseRange.lowerBound + adjustment)...(baseRange.upperBound + adjustment)
        
        // Analyze sleep patterns
        let patterns = analyzeSleepPatterns(sleepData)
        
        // Generate optimal schedule using the generator
        let schedule = SleepRecommendationGenerator.calculateOptimalSchedule(
            patterns: patterns,
            targetDuration: adjustedRange.lowerBound
        )
        
        // Create recommendations using the generator
        return SleepRecommendations(
            recommendedSleepDuration: adjustedRange,
            suggestedBedtime: schedule.bedtime,
            suggestedWakeTime: schedule.wakeTime,
            consistencyScore: patterns.consistencyScore,
            qualityTips: SleepRecommendationGenerator.generateQualityTips(from: patterns),
            scheduleAdjustments: SleepRecommendationGenerator.generateScheduleAdjustments(from: patterns)
        )
    }
    
    /// Analyze recent sleep sessions to identify patterns
    private func analyzeSleepPatterns(_ sessions: [SleepSession]) -> SleepPatterns {
        let durations = sessions.compactMap { session -> TimeInterval? in
            guard let start = session.startTime,
                  let end = session.endTime else { return nil }
            return end.timeIntervalSince(start)
        }
        
        let bedtimes = sessions.compactMap { $0.startTime }
        let waketimes = sessions.compactMap { $0.endTime }
        
        // Calculate consistency score based on timing variations
        let bedtimeVariation = calculateTimeVariation(bedtimes)
        let waketimeVariation = calculateTimeVariation(waketimes)
        let consistencyScore = 100 - (bedtimeVariation + waketimeVariation) / 2
        
        // Identify common sleep issues
        let qualityScores = sessions.compactMap { $0.qualityScore }
        let averageQuality = qualityScores.reduce(0, +) / Double(qualityScores.count)
        
        return SleepPatterns(
            averageDuration: durations.reduce(0, +) / Double(durations.count),
            averageBedtime: calculateAverageTime(bedtimes),
            averageWakeTime: calculateAverageTime(waketimes),
            consistencyScore: consistencyScore,
            averageQuality: averageQuality,
            commonIssues: identifyCommonIssues(sessions)
        )
    }
    
    /// Calculate variation in time points (lower is more consistent)
    private func calculateTimeVariation(_ times: [Date]) -> Double {
        guard !times.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let components = times.map { calendar.dateComponents([.hour, .minute], from: $0) }
        let minutes = components.map { Double($0.hour! * 60 + $0.minute!) }
        
        let average = minutes.reduce(0, +) / Double(minutes.count)
        let variance = minutes.map { pow($0 - average, 2) }.reduce(0, +) / Double(minutes.count)
        
        return sqrt(variance)
    }
    
    /// Calculate average time while handling day wrapping
    private func calculateAverageTime(_ times: [Date]) -> Date? {
        guard !times.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let components = times.map { calendar.dateComponents([.hour, .minute], from: $0) }
        let totalMinutes = components.reduce(0) { $0 + $1.hour! * 60 + $1.minute! }
        let averageMinutes = totalMinutes / components.count
        
        let hours = averageMinutes / 60
        let minutes = averageMinutes % 60
        
        return calendar.date(bySettingHour: hours, minute: minutes, second: 0, of: Date())
    }
    
    private func identifyCommonIssues(_ sessions: [SleepSession]) -> [SleepIssue] {
        var issues: [SleepIssue] = []
        
        // Check for late bedtimes
        if let lateBedtime = checkLateBedtimes(sessions) {
            issues.append(lateBedtime)
        }
        
        // Check for irregular schedules
        if let irregularity = checkScheduleIrregularity(sessions) {
            issues.append(irregularity)
        }
        
        // Check environmental factors
        if let environmental = checkEnvironmentalIssues(sessions) {
            issues.append(environmental)
        }
        
        return issues
    }
    
    private func checkLateBedtimes(_ sessions: [SleepSession]) -> SleepIssue? {
        let calendar = Calendar.current
        let lateBedtimeCount = sessions.filter { session in
            guard let startTime = session.startTime else { return false }
            let hour = calendar.component(.hour, from: startTime)
            return hour >= 23 || hour < 5
        }.count
        
        if Double(lateBedtimeCount) / Double(sessions.count) > 0.5 {
            return SleepIssue(
                type: .lateBedtime,
                description: "Frequent late bedtimes detected",
                recommendation: "Try to start your bedtime routine 1 hour earlier"
            )
        }
        return nil
    }
    
    private func checkScheduleIrregularity(_ sessions: [SleepSession]) -> SleepIssue? {
        let bedtimes = sessions.compactMap { $0.startTime }
        let variation = calculateTimeVariation(bedtimes)
        
        if variation > 60 { // More than 1 hour variation
            return SleepIssue(
                type: .irregularSchedule,
                description: "Your sleep schedule varies significantly",
                recommendation: "Try to maintain consistent sleep and wake times"
            )
        }
        return nil
    }
    
    private func checkEnvironmentalIssues(_ sessions: [SleepSession]) -> SleepIssue? {
        let environmentalIssues = sessions.filter { session in
            guard let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading] else {
                return false
            }
            
            let highNoiseCount = readings.filter { $0.noiseLevel > 50 }.count
            let highLightCount = readings.filter { $0.lightLevel > 20 }.count
            
            return Double(highNoiseCount + highLightCount) / Double(readings.count) > 0.3
        }.count
        
        if Double(environmentalIssues) / Double(sessions.count) > 0.3 {
            return SleepIssue(
                type: .poorEnvironment,
                description: "Your sleep environment could be improved",
                recommendation: "Consider using earplugs or a sleep mask"
            )
        }
        return nil
    }
    
    private func fetchRecentSleepData() async throws -> [SleepSession] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(format: "endTime >= %@",
            Calendar.current.date(byAdding: .day, value: -30, to: Date())! as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: false)]
        
        return try context.fetch(request)
    }
}
