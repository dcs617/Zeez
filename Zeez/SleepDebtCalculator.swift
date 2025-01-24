import Foundation
import CoreData

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
        let hoursPerNight = weeklyDebt / (7 * 3600) // Convert to hours
        
        switch hoursPerNight {
        case ..<1:
            return RecoveryPlan(
                recommendedAction: "Add 30 minutes to your nightly sleep",
                timeToRecover: "1 week",
                severity: .mild
            )
        case 1..<2:
            return RecoveryPlan(
                recommendedAction: "Add 1 hour to your nightly sleep",
                timeToRecover: "2 weeks",
                severity: .moderate
            )
        default:
            return RecoveryPlan(
                recommendedAction: "Gradually increase sleep by 1-2 hours",
                timeToRecover: "3-4 weeks",
                severity: .severe
            )
        }
    }
    
    /// Calculate the trend of sleep debt (improving or worsening)
    private func calculateDebtTrend(sessions: [SleepSession]) -> DebtTrend {
        guard sessions.count >= 14,
              let firstWeekSessions = sessions.prefix(7).first?.startTime,
              let secondWeekSessions = sessions.suffix(7).first?.startTime else {
            return .stable
        }
        
        let firstWeekAvg = calculateAverageSleep(for: Array(sessions.prefix(7)))
        let secondWeekAvg = calculateAverageSleep(for: Array(sessions.suffix(7)))
        
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
