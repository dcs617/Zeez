import Foundation
import CoreData

// Temporary types to maintain compilation during Phase 1A cleanup
// These will be removed/simplified in Phase 2 implementation

// SessionInfo wrapper around SleepSession for temporary compatibility
struct SessionInfo {
    let session: SleepSession
    let id: UUID
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    
    var durationHours: Double {
        return duration / 3600.0
    }
    
    init(session: SleepSession) {
        self.session = session
        self.id = session.id ?? UUID()
        self.startTime = session.startTime ?? Date()
        self.endTime = session.endTime ?? Date()
        self.duration = self.endTime.timeIntervalSince(self.startTime)
    }
}

// Simple cycle analysis stub
struct CycleAnalysis {
    let cycleCount: Int
    let completedCycles: Int
    let consistency: Double
    
    static let empty = CycleAnalysis(cycleCount: 0, completedCycles: 0, consistency: 0.0)
}

// Analysis result stub (may still be needed by some components)
struct AnalysisResult {
    let success: Bool
    let error: Error?
}

enum SleepGoalPolicy {
    static func duration(from bedtime: Date, to wakeTime: Date) -> TimeInterval {
        let interval = wakeTime.timeIntervalSince(bedtime)
        return interval > 0 ? interval : interval + 24 * 3600
    }
}

// Trend direction enum
enum TrendDirection {
    case improving
    case declining
    case stable
    case unknown
}

// Personalization types stubs
struct PersonalizedBaselines {
    let optimalBedtime: Date
    let targetSleepDuration: TimeInterval
    let dataMaturity: Double
    let confidence: Double
    let sessionCount: Int
    let averageSleepDuration: TimeInterval
    let bedtimeConsistency: Double
    let wakeTimeConsistency: Double
    let sleepDurationVariability: TimeInterval
    
    static let mock = PersonalizedBaselines(
        optimalBedtime: Date(),
        targetSleepDuration: 8 * 3600,
        dataMaturity: 0.5,
        confidence: 0.7,
        sessionCount: 30,
        averageSleepDuration: 7.5 * 3600,
        bedtimeConsistency: 0.85,
        wakeTimeConsistency: 0.80,
        sleepDurationVariability: 0.5 * 3600 // 30 minutes variability
    )
}

struct QualityTrends {
    let trend: TrendDirection
    let averageScore: Double
}

struct SleepPatternAnalysis {
    let consistencyScore: Double
    let weekdayPattern: String
    let weekendPattern: String
    let trendDirection: TrendDirection
    let confidence: Double
    let qualityTrends: QualityTrends
    
    static let mock = SleepPatternAnalysis(
        consistencyScore: 75.0,
        weekdayPattern: "Regular",
        weekendPattern: "Delayed",
        trendDirection: .stable,
        confidence: 0.8,
        qualityTrends: QualityTrends(trend: .stable, averageScore: 78.0)
    )
}

// Analyzer stubs
class PersonalizationManager {
    static let shared = PersonalizationManager()
    
    private init() {}
    
    func getPersonalizedBaselines(context: NSManagedObjectContext) async -> PersonalizedBaselines {
        return PersonalizedBaselines.mock
    }
    
    func calculatePersonalizedBaselines() async -> PersonalizedBaselines {
        return PersonalizedBaselines.mock
    }
}

class HistoricalAnalyzer {
    init() {}
    
    func analyzeSleepPatterns(context: NSManagedObjectContext) async -> SleepPatternAnalysis {
        return SleepPatternAnalysis.mock
    }
    
    // Alternative method signature used by PersonalizationSettingsView
    func analyzeSleepPatterns(days: Int) async -> SleepPatternAnalysis {
        return SleepPatternAnalysis.mock
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

    func calculateRecoveryDays(debtHours: Double) -> Int {
        guard debtHours > 0 else { return 0 }
        return Int(ceil(debtHours))
    }

    func getDebtSeverity(debtHours: Double) -> DebtSeverity {
        switch debtHours {
        case ..<2: return .minimal
        case 2..<7: return .moderate
        case 7..<14: return .significant
        default: return .severe
        }
    }
}
