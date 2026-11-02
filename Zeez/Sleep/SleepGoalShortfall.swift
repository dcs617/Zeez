import Foundation
import CoreData

// The user's sleep goal compared with recorded nights: the goal's duration, and the
// per-night shortfall shown by Sleep Goal settings and Learn's sleep-debt screen.

enum SleepGoalPolicy {
    /// The goal's length on the clock: 11 PM to 7 AM is 8 hours, whatever days the two stored
    /// dates fall on and whether the clocks change between them. Elapsed time read a goal set
    /// on the night the clocks go back as 9 hours, and two dates set on different days as days.
    static func duration(from bedtime: Date, to wakeTime: Date, calendar: Calendar = .current) -> TimeInterval {
        func clockMinutes(_ date: Date) -> Int {
            let components = calendar.dateComponents([.hour, .minute], from: date)
            return (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
        var minutes = clockMinutes(wakeTime) - clockMinutes(bedtime)
        if minutes <= 0 { minutes += 24 * 60 }
        return TimeInterval(minutes * 60)
    }
}

struct SleepGoalShortfallDay: Identifiable {
    let date: Date
    let comparedDuration: TimeInterval
    let shortfall: TimeInterval
    let includesEstimatedDuration: Bool

    var id: Date { date }
}

struct SleepGoalShortfallSummary {
    let goalDuration: TimeInterval
    let periodDays: Int
    let days: [SleepGoalShortfallDay]

    var coveredDayCount: Int { days.count }
    var totalShortfall: TimeInterval { days.reduce(0) { $0 + $1.shortfall } }
    var averageComparedDuration: TimeInterval {
        guard !days.isEmpty else { return 0 }
        return days.reduce(0) { $0 + $1.comparedDuration } / Double(days.count)
    }
    var usesEstimatedDurations: Bool { days.contains { $0.includesEstimatedDuration } }
}

final class SleepDebtCalculator {
    static let shared = SleepDebtCalculator()

    private init() {}

    /// Computes recorded sleep goal shortfall without inventing values for nights
    /// where the app has no usable sleep duration.
    func summary(
        forDays days: Int = 7,
        endingAt endDate: Date = Date(),
        context: NSManagedObjectContext
    ) -> SleepGoalShortfallSummary? {
        guard days > 0,
              let preferences = try? context.fetch(UserPreferences.fetchRequest()).first,
              preferences.sleepGoalEnabled,
              preferences.targetSleepDuration > 0 else {
            return nil
        }

        let calendar = Calendar.current
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: endDate)) ?? endDate
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "isActive == NO AND startTime >= %@ AND startTime < %@",
            startDate as NSDate,
            endExclusive as NSDate
        )

        guard let sessions = try? context.fetch(request) else { return nil }
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startTime ?? startDate)
        }
        let dailyResults = grouped.compactMap { date, sessions -> SleepGoalShortfallDay? in
            let usable = sessions.compactMap { session -> (TimeInterval, Bool)? in
                let metrics = session.derivedSleepMetrics
                guard let duration = metrics.goalComparisonDuration.value,
                      metrics.goalShortfall(for: preferences.targetSleepDuration).value != nil else {
                    return nil
                }
                return (duration, metrics.goalComparisonDuration.provenance == .recordedSession)
            }
            guard !usable.isEmpty else { return nil }
            let duration = usable.reduce(0) { $0 + $1.0 }
            return SleepGoalShortfallDay(
                date: date,
                comparedDuration: duration,
                shortfall: max(0, preferences.targetSleepDuration - duration),
                includesEstimatedDuration: usable.contains { $0.1 }
            )
        }
        .sorted { $0.date < $1.date }

        return SleepGoalShortfallSummary(
            goalDuration: preferences.targetSleepDuration,
            periodDays: days,
            days: dailyResults
        )
    }

    func calculateCurrentDebt(context: NSManagedObjectContext) -> Double {
        summary(context: context)?.totalShortfall ?? 0
    }

    func getRecommendedSleepDuration(context: NSManagedObjectContext) -> Double {
        let preferences = try? context.fetch(UserPreferences.fetchRequest()).first
        return (preferences?.targetSleepDuration ?? 0) / 3600
    }

    func getAverageSleepTime(forDays days: Int, context: NSManagedObjectContext) -> Double {
        (summary(forDays: days, context: context)?.averageComparedDuration ?? 0) / 3600
    }

    func getDebtHistory(forDays days: Int, context: NSManagedObjectContext) -> [(Date, Double)] {
        summary(forDays: days, context: context)?.days.map { ($0.date, $0.shortfall / 3600) } ?? []
    }
}
