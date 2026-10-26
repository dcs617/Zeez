import CoreData
import SwiftUI
import os.log

/// Provides aggregated monthly sleep data for trend analysis
class MonthlyTrendsDataProvider {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Fetches monthly trend data for the `months` calendar months ending at `now`.
    ///
    /// Runs on the context's queue: this is a nonisolated async method, so without
    /// `perform` it would read the view context off the main thread.
    func fetchMonthlyTrends(months: Int = 6, now: Date = Date()) async throws -> MonthlyTrendData {
        try await context.perform { [self] in
            let endDate = now
            let startDate = Calendar.current.date(
                byAdding: .month,
                value: -(months - 1),
                to: endDate
            )?.startOfMonth() ?? endDate

            let request = SleepSession.fetchRequest()
            request.predicate = NSPredicate(
                format: "startTime >= %@ AND endTime <= %@ AND isActive == NO",
                startDate as NSDate,
                endDate as NSDate
            )
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: true)
            ]

            let sessions = try context.fetch(request)
            return aggregateMonthlyData(sessions, start: startDate, end: endDate)
        }
    }

    private func aggregateMonthlyData(
        _ sessions: [SleepSession],
        start: Date,
        end: Date
    ) -> MonthlyTrendData {
        var monthlyData: [Date: MonthlyMetrics] = [:]
        let calendar = Calendar.current
        
        var currentDate = start
        while currentDate <= end {
            monthlyData[currentDate] = MonthlyMetrics()
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? end
        }
        
        // Aggregate session data by month
        for session in sessions {
            guard let startTime = session.startTime,
                  let monthStart = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: startTime)
                  ) else { continue }
            
            monthlyData[monthStart]?.addSession(session)
        }
        
        var dataPoints: [MonthlyDataPoint] = []
        for month in monthlyData.keys.sorted() {
            guard let metrics = monthlyData[month] else { continue }
            dataPoints.append(MonthlyDataPoint(
                month: month,
                metrics: metrics,
                sleepDebt: calculateSleepGoalShortfall(metrics)
            ))
        }

        return MonthlyTrendData(
            dataPoints: dataPoints,
            insights: generateMonthlyInsights(dataPoints)
        )
    }

    /// `nil` without a selected goal or without a recorded night: a month with nothing to
    /// compare is not a month that met the goal.
    private func calculateSleepGoalShortfall(_ metrics: MonthlyMetrics) -> TimeInterval? {
        guard metrics.sessionCount > 0 else { return nil }
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        guard let preferences = try? context.fetch(request).first,
              preferences.sleepGoalEnabled,
              preferences.targetSleepDuration > 0 else {
            return nil
        }
        return metrics.goalShortfall(targetDuration: preferences.targetSleepDuration)
    }

    private func generateMonthlyInsights(_ data: [MonthlyDataPoint]) -> [MonthlyInsight] {
        var insights: [MonthlyInsight] = []
        
        // Analyze trends
        if data.count >= 2 {
            let recent = data.suffix(2)
            guard let current = recent.last,
                  let previous = recent.first else {
                ZeezLogger.error(ZeezLogger.ui, "Failed to get trend comparison data")
                return insights
            }
            
            // Estimate trends, only between two months that both have estimates. A month
            // without one used to count as 0, reporting a trend in the missing data.
            if let currentQuality = current.metrics.averageQuality,
               let previousQuality = previous.metrics.averageQuality {
                if currentQuality > previousQuality + 5 {
                    insights.append(.qualityImproving)
                } else if currentQuality < previousQuality - 5 {
                    insights.append(.qualityDeclining)
                }
            }

            // Sleep-debt and environmental insights are omitted until the underlying
            // measurements and computation are production-ready and data-backed.
        }

        // An observation, not a grade: the contract's wording for schedule regularity.
        if let spread = data.last?.metrics.startTimeSpread {
            insights.append(.startTimeSpread(spread))
        }

        return insights
    }
}

// MARK: - Supporting Types

struct MonthlyTrendData {
    let dataPoints: [MonthlyDataPoint]
    let insights: [MonthlyInsight]
}

/// Each optional is `nil` when the month cannot support the value; charts leave such a
/// month out rather than plotting a zero (claims rule 4).
struct MonthlyDataPoint: Identifiable {
    let id = UUID()
    let month: Date
    let metrics: MonthlyMetrics
    let sleepDebt: TimeInterval?
}

class MonthlyMetrics {
    private(set) var sessionCount = 0
    private(set) var totalRecordedDuration: TimeInterval = 0
    private(set) var totalQuality: Double = 0
    private var qualityCount = 0
    private var recordings: [(start: Date, duration: TimeInterval)] = []
    /// What the sleep goal is compared with, per day: Apple Health time asleep, or a Zeez
    /// session's recorded interval (`durationForSleepGoalComparison`).
    private var goalDurationsByDay: [Date: TimeInterval] = [:]

    /// Mean recorded session interval (end − start) for every source — the quantity the weekly
    /// "Recorded Session Duration" card shows. Not time asleep (claims rule 7); it used to mix in
    /// Apple Health time asleep for imported nights.
    var averageRecordedDuration: TimeInterval? {
        sessionCount > 0 ? totalRecordedDuration / Double(sessionCount) : nil
    }

    /// Mean of the month's current-version Experimental Zeez Estimates; `nil` when it has none.
    var averageQuality: Double? {
        qualityCount > 0 ? totalQuality / Double(qualityCount) : nil
    }

    /// `nil` below `SleepStartSpread.minimumNights` recorded nights.
    var startTimeSpread: SleepStartSpread? {
        SleepStartSpread.calculate(recordings: recordings)
    }
    
    func addSession(_ session: SleepSession) {
        guard let startTime = session.startTime, session.recordedInterval > 0 else { return }

        sessionCount += 1
        totalRecordedDuration += session.recordedInterval
        if session.hasCurrentVersionEstimate {
            totalQuality += session.qualityScore
            qualityCount += 1
        }

        recordings.append((start: startTime, duration: session.recordedInterval))
        if let goalDuration = session.durationForSleepGoalComparison {
            goalDurationsByDay[Calendar.current.startOfDay(for: startTime), default: 0] += goalDuration
        }
    }

    /// `nil` when no session has a duration the goal can be compared with.
    func goalShortfall(targetDuration: TimeInterval) -> TimeInterval? {
        guard !goalDurationsByDay.isEmpty else { return nil }
        return goalDurationsByDay.values.reduce(0) { total, duration in
            total + max(0, targetDuration - duration)
        }
    }
}

enum MonthlyInsight {
    case qualityImproving
    case qualityDeclining
    case startTimeSpread(SleepStartSpread)
    case belowSelectedGoal
    case environmentalImprovementNeeded(recommendations: [EnvironmentalRecommendation])
    
    var description: String {
        switch self {
        case .qualityImproving:
            return "Experimental Zeez estimate is increasing"
        case .qualityDeclining:
            return "Experimental Zeez estimate is decreasing"
        case .startTimeSpread(let spread):
            return "Your recorded sleep start time varied by about \(spread.minutes) minutes over \(spread.nights) nights this month"
        case .belowSelectedGoal:
            return "Recorded sleep is below your selected goal"
        case .environmentalImprovementNeeded(let recommendations):
            return "Environmental improvements suggested:\n" +
                   recommendations.map { "• \($0.description)" }.joined(separator: "\n")
        }
    }
    
    var icon: String {
        switch self {
        case .qualityImproving:
            return "chart.line.uptrend.xyaxis"
        case .qualityDeclining:
            return "chart.line.downtrend.xyaxis"
        case .startTimeSpread:
            return "clock"
        case .belowSelectedGoal:
            return "zzz"
        case .environmentalImprovementNeeded:
            return "leaf"
        }
    }
}

private extension Date {
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
}
