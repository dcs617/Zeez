import Foundation
import CoreData
import os.log

/// Calculates and tracks sleep debt based on user's sleep goals and actual sleep duration
final class SleepDebtCalculator {
    static let shared = SleepDebtCalculator()
    private let persistenceController: PersistenceController
    
    private init() {
        self.persistenceController = .shared
    }
    
    /// Calculate sleep debt metrics for a user
    /// - Returns: Analysis of current sleep debt status and recommendations
    func calculateSleepDebtMetrics() async throws -> SleepDebtMetrics {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        
        // Get sessions from the last 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        request.predicate = NSPredicate(format: "startTime >= %@", thirtyDaysAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: true)]
        
        let sessions = try context.fetch(request)
        let preferences = context.fetchUserPreferences()

        guard let targetDuration = preferences?.targetSleepDuration,
              targetDuration > 0 else {
            throw SleepError.noSleepGoalSet
        }
        
        // Calculate weekly and monthly debt
        let weeklyDebt = try calculateWeeklyDebt(
            sessions: sessions,
            targetDuration: targetDuration
        )
        
        let monthlyDebt = try calculateMonthlyDebt(
            sessions: sessions,
            targetDuration: targetDuration
        )
        
        // Generate recovery suggestions
        let recoveryPlan = createRecoveryPlan(
            weeklyDebt: weeklyDebt,
            monthlyDebt: monthlyDebt
        )
        
        return SleepDebtMetrics(
            weeklyDebt: weeklyDebt,
            monthlyDebt: monthlyDebt,
            debtTrend: calculateDebtTrend(sessions: sessions),
            recoveryPlan: recoveryPlan
        )
    }
    
    /// Calculate sleep debt for the past week
    private func calculateWeeklyDebt(
        sessions: [SleepSession],
        targetDuration: TimeInterval
    ) throws -> TimeInterval {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        let weekSessions = sessions.filter { session in
            guard let startTime = session.startTime else { return false }
            return startTime >= weekAgo
        }
        
        return try calculateDebt(
            for: weekSessions,
            targetDuration: targetDuration,
            expectedDays: 7
        )
    }
    
    /// Calculate sleep debt for the past month
    private func calculateMonthlyDebt(
        sessions: [SleepSession],
        targetDuration: TimeInterval
    ) throws -> TimeInterval {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        let monthSessions = sessions.filter { session in
            guard let startTime = session.startTime else { return false }
            return startTime >= monthAgo
        }
        
        return try calculateDebt(
            for: monthSessions,
            targetDuration: targetDuration,
            expectedDays: 30
        )
    }
    
    /// Calculate debt for a given set of sessions
    private func calculateDebt(
        for sessions: [SleepSession],
        targetDuration: TimeInterval,
        expectedDays: Int
    ) throws -> TimeInterval {
        let totalSleepTime = sessions.reduce(0) { total, session in
            guard let start = session.startTime,
                  let end = session.endTime else { return total }
            return total + end.timeIntervalSince(start)
        }
        
        let expectedSleep = targetDuration * Double(expectedDays)
        return expectedSleep - totalSleepTime
    }
    
    /// Create a recovery plan based on current sleep debt
    private func createRecoveryPlan(
        weeklyDebt: TimeInterval,
        monthlyDebt: TimeInterval
    ) -> RecoveryPlan {
        let weeklyHours = weeklyDebt / 3600 // Convert to hours
        let severity = getDebtSeverity(debtHours: weeklyHours)
        
        return RecoveryPlan(
            recommendedAction: severity.recommendations.first ?? "Maintain consistent sleep schedule",
            timeToRecover: calculateRecoveryTime(debtHours: weeklyHours),
            severity: severity
        )
    }
    
    /// Get debt severity level based on hours of debt
    func getDebtSeverity(debtHours: Double) -> DebtSeverity {
        if debtHours <= 2 {
            return .minimal
        } else if debtHours <= 5 {
            return .moderate
        } else if debtHours <= 10 {
            return .significant
        } else {
            return .severe
        }
    }
    
    /// Calculate recovery time based on debt hours
    private func calculateRecoveryTime(debtHours: Double) -> String {
        let days = calculateRecoveryDays(debtHours: debtHours)
        
        switch days {
        case 0...3: return "\(days) days"
        case 4...10: return "1-2 weeks"
        case 11...21: return "2-3 weeks"
        default: return "3-4 weeks"
        }
    }
    
    /// Calculate number of recovery days needed
    func calculateRecoveryDays(debtHours: Double) -> Int {
        // Recovery rate assumptions:
        // - Can recover up to 1 hour per night on weekdays
        // - Can recover up to 2 hours per night on weekends
        
        var remainingDebt = debtHours
        var days = 0
        
        while remainingDebt > 0 && days < 30 { // Cap at 30 days
            days += 1
            let isWeekend = Calendar.current.isDateInWeekend(
                Date().addingTimeInterval(TimeInterval(days) * 24 * 3600)
            )
            remainingDebt -= isWeekend ? 2.0 : 1.0
        }
        
        return days
    }
    
    /// Get current debt for display purposes
    func calculateCurrentDebt(context: NSManagedObjectContext) -> Double {
        let request: NSFetchRequest<DailyMetrics> = DailyMetrics.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyMetrics.date, ascending: false)]
        request.predicate = NSPredicate(
            format: "date >= %@",
            Calendar.current.date(byAdding: .day, value: -30, to: Date())! as NSDate
        )
        
        guard let metrics = try? context.fetch(request) else { return 0 }
        let totalDebt = metrics.reduce(0) { $0 + ($1.sleepDebt) }
        
        return totalDebt
    }
    
    /// Get average sleep time for a given period
    func getAverageSleepTime(forDays days: Int, context: NSManagedObjectContext) -> Double {
        let request: NSFetchRequest<DailyMetrics> = DailyMetrics.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyMetrics.date, ascending: false)]
        request.predicate = NSPredicate(
            format: "date >= %@",
            Calendar.current.date(byAdding: .day, value: -days, to: Date())! as NSDate
        )
        
        guard let metrics = try? context.fetch(request) else { return 0 }
        let totalSleep = metrics.reduce(0) { $0 + $1.totalSleepTime }
        
        return totalSleep / Double(metrics.count)
    }
    
    /// Get debt history for charting
    func getDebtHistory(forDays days: Int, context: NSManagedObjectContext) -> [(Date, Double)] {
        let request: NSFetchRequest<DailyMetrics> = DailyMetrics.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyMetrics.date, ascending: true)]
        request.predicate = NSPredicate(
            format: "date >= %@",
            Calendar.current.date(byAdding: .day, value: -days, to: Date())! as NSDate
        )
        
        guard let metrics = try? context.fetch(request) else { return [] }
        
        return metrics.compactMap { metric in
            guard let date = metric.date else { return nil }
            return (date, metric.sleepDebt)
        }
    }
    
    /// Get recommended sleep duration from user preferences
    func getRecommendedSleepDuration(context: NSManagedObjectContext) -> Double {
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.fetchLimit = 1
        
        if let preferences = try? context.fetch(request).first,
           preferences.targetSleepDuration > 0 {
            return preferences.targetSleepDuration
        }
        
        // Default to 8 hours if no preference set
        return 8.0
    }
    
    /// Calculate the trend of sleep debt (improving or worsening)
    private func calculateDebtTrend(sessions: [SleepSession]) -> DebtTrend {
        guard sessions.count >= 14 else {
            return .stable
        }
        
        // Verify we have enough data across the time range
        let firstWeek = Array(sessions.prefix(7))
        let secondWeek = Array(sessions.suffix(7))
        
        guard !firstWeek.isEmpty && !secondWeek.isEmpty,
              let firstWeekStart = firstWeek.first?.startTime,
              let secondWeekStart = secondWeek.first?.startTime else {
            return .stable
        }
        
        // Ensure we have sufficient time span between weeks
        let timeDifference = secondWeekStart.timeIntervalSince(firstWeekStart)
        guard timeDifference >= 7 * 24 * 3600 else { // At least 7 days apart
            return .stable
        }
        
        let firstWeekAvg = calculateAverageSleep(for: firstWeek)
        let secondWeekAvg = calculateAverageSleep(for: secondWeek)
        
        let difference = secondWeekAvg - firstWeekAvg
        
        switch difference {
        case ..<(-1800): return .worsening  // More than 30 minutes worse
        case 1800...: return .improving     // More than 30 minutes better
        default: return .stable
        }
    }
    
    /// Calculate average sleep duration for a set of sessions
    private func calculateAverageSleep(for sessions: [SleepSession]) -> TimeInterval {
        let totalSleep = sessions.reduce(0) { total, session in
            guard let start = session.startTime,
                  let end = session.endTime else { return total }
            return total + end.timeIntervalSince(start)
        }
        return totalSleep / Double(sessions.count)
    }
}

/// Error types for sleep calculations
enum SleepError: LocalizedError {
    case noSleepGoalSet
    case insufficientData
    
    var errorDescription: String? {
        switch self {
        case .noSleepGoalSet:
            return "Please set a sleep goal to calculate sleep debt"
        case .insufficientData:
            return "Not enough sleep data to calculate debt"
        }
    }
}
