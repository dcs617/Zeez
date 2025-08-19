import CoreData
import SwiftUI
import os.log

/// Provides aggregated monthly sleep data for trend analysis
class MonthlyTrendsDataProvider {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Fetches monthly trend data for the specified number of months
    func fetchMonthlyTrends(months: Int = 6) async throws -> MonthlyTrendData {
        let endDate = Date()
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
        return try await aggregateMonthlyData(sessions, start: startDate, end: endDate)
    }
    
    private func aggregateMonthlyData(
        _ sessions: [SleepSession],
        start: Date,
        end: Date
    ) async throws -> MonthlyTrendData {
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
        
        // Calculate rolling averages and patterns
        var rollingData: [MonthlyDataPoint] = []
        let months = monthlyData.keys.sorted()
        
        for month in months {
            guard let metrics = monthlyData[month] else { continue }
            
            let previousMonths = months.prefix { $0 <= month }
                .compactMap { monthlyData[$0] }
            
            let dataPoint = MonthlyDataPoint(
                month: month,
                metrics: metrics,
                rollingAverage: calculateRollingAverage(previousMonths),
                sleepDebt: calculateSleepDebt(previousMonths),
                consistency: calculateConsistency(metrics)
            )
            
            rollingData.append(dataPoint)
        }
        
        // Generate insights
        let insights = try await generateMonthlyInsights(rollingData)
        
        return MonthlyTrendData(
            dataPoints: rollingData,
            insights: insights
        )
    }
    
    private func calculateRollingAverage(_ months: [MonthlyMetrics]) -> RollingAverages {
        let durations = months.map { $0.averageDuration }
        let qualities = months.map { $0.averageQuality }
        
        return RollingAverages(
            duration: durations.average ?? 0,
            quality: qualities.average ?? 0
        )
    }
    
    private func calculateSleepDebt(_ months: [MonthlyMetrics]) -> TimeInterval {
        let targetSleep: TimeInterval = AppConstants.Sleep.targetDuration // 8 hours in seconds
        let recentMonths = Array(months.suffix(3)) // Last 3 months
        
        return recentMonths.reduce(0) { total, metrics in
            total + (targetSleep - metrics.averageDuration) * Double(metrics.sessionCount)
        }
    }
    
    private func calculateConsistency(_ metrics: MonthlyMetrics) -> Double {
        let bedtimeVariance = metrics.bedtimeVariance
        let durationVariance = metrics.durationVariance
        
        // Convert variances to consistency scores (inverse relationship)
        let maxBedtimeVariance: TimeInterval = 3600 // 1 hour variance = 0% consistency
        let maxDurationVariance: TimeInterval = 7200 // 2 hour variance = 0% consistency
        
        let bedtimeConsistency = max(0, 100 - (bedtimeVariance / maxBedtimeVariance * 100))
        let durationConsistency = max(0, 100 - (durationVariance / maxDurationVariance * 100))
        
        return (bedtimeConsistency + durationConsistency) / 2
    }
    
    private func generateMonthlyInsights(_ data: [MonthlyDataPoint]) async throws -> [MonthlyInsight] {
        var insights: [MonthlyInsight] = []
        
        // Analyze trends
        if data.count >= 2 {
            let recent = data.suffix(2)
            guard let current = recent.last,
                  let previous = recent.first else {
                ZeezLogger.error(ZeezLogger.ui, "Failed to get trend comparison data")
                return insights
            }
            
            // Quality trends
            if current.metrics.averageQuality > previous.metrics.averageQuality + 5 {
                insights.append(.qualityImproving)
            } else if current.metrics.averageQuality < previous.metrics.averageQuality - 5 {
                insights.append(.qualityDeclining)
            }
            
            // Consistency insights
            if current.consistency > 80 {
                insights.append(.highConsistency)
            } else if current.consistency < 60 {
                insights.append(.lowConsistency)
            }
            
            // Sleep debt insights
            if current.sleepDebt > 14400 { // 4 hours
                insights.append(.significantSleepDebt)
            }
        }
        
        // Environmental impact insights
        let environmentalAnalyzer = EnvironmentalAnalyzer(context: context)
        if let latestSession = try context.fetch(SleepSession.fetchRequest()).last {
            let analysis = try await environmentalAnalyzer.analyzeSession(latestSession)
            
            if !analysis.recommendations.isEmpty {
                insights.append(.environmentalImprovementNeeded(
                    recommendations: analysis.recommendations
                ))
            }
        }
        
        return insights
    }
}

// MARK: - Supporting Types

struct MonthlyTrendData {
    let dataPoints: [MonthlyDataPoint]
    let insights: [MonthlyInsight]
}

struct MonthlyDataPoint: Identifiable {
    let id = UUID()
    let month: Date
    let metrics: MonthlyMetrics
    let rollingAverage: RollingAverages
    let sleepDebt: TimeInterval
    let consistency: Double
}

class MonthlyMetrics {
    private(set) var sessionCount = 0
    private(set) var totalDuration: TimeInterval = 0
    private(set) var totalQuality: Double = 0
    private var bedtimes: [TimeInterval] = []
    private var durations: [TimeInterval] = []
    
    var averageDuration: TimeInterval {
        sessionCount > 0 ? totalDuration / Double(sessionCount) : 0
    }
    
    var averageQuality: Double {
        sessionCount > 0 ? totalQuality / Double(sessionCount) : 0
    }
    
    var bedtimeVariance: TimeInterval {
        bedtimes.variance ?? 0
    }
    
    var durationVariance: TimeInterval {
        durations.variance ?? 0
    }
    
    func addSession(_ session: SleepSession) {
        guard let startTime = session.startTime,
              let endTime = session.endTime else { return }
        
        sessionCount += 1
        let duration = endTime.timeIntervalSince(startTime)
        totalDuration += duration
        totalQuality += session.qualityScore
        
        // Store normalized bedtime (seconds since start of day)
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: startTime)
        let bedtime = TimeInterval(components.hour ?? 0) * 3600 +
                     TimeInterval(components.minute ?? 0) * 60 +
                     TimeInterval(components.second ?? 0)
        bedtimes.append(bedtime)
        durations.append(duration)
    }
}

struct RollingAverages {
    let duration: TimeInterval
    let quality: Double
}

enum MonthlyInsight {
    case qualityImproving
    case qualityDeclining
    case highConsistency
    case lowConsistency
    case significantSleepDebt
    case environmentalImprovementNeeded(recommendations: [EnvironmentalRecommendation])
    
    var description: String {
        switch self {
        case .qualityImproving:
            return "Sleep quality is improving"
        case .qualityDeclining:
            return "Sleep quality needs attention"
        case .highConsistency:
            return "Excellent sleep schedule consistency"
        case .lowConsistency:
            return "Consider stabilizing your sleep schedule"
        case .significantSleepDebt:
            return "Significant sleep debt detected"
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
        case .highConsistency:
            return "checkmark.circle"
        case .lowConsistency:
            return "exclamationmark.circle"
        case .significantSleepDebt:
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
