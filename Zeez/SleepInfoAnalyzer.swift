import Foundation
import CoreData
import SwiftUI

struct SleepAnalysis {
    let timeMetrics: TimeMetrics
    let efficiencyMetrics: EfficiencyMetrics
    let environmentalMetrics: EnvironmentalMetrics
    let trendsMetrics: TrendMetrics
}

struct TimeMetrics {
    let totalTime: TimeInterval
    let timeInBed: TimeInterval
    let timeToFallAsleep: TimeInterval
    let timeAwake: TimeInterval
    let bedtime: Date
    let wakeTime: Date
    let comparison: ComparisonMetrics
}

struct ComparisonMetrics {
    let averageSleepTime: TimeInterval
    let sleepGoal: TimeInterval
    let bedtimeTrend: TrendDirection
    let durationTrend: TrendDirection
}

struct EfficiencyMetrics {
    let overall: Double
    let trend: TrendDirection
    let factorScores: [EfficiencyFactor]
    
    struct EfficiencyFactor: Identifiable {
        let id = UUID()
        let name: String
        let score: Double
        let icon: String
        let color: Color
    }
}

struct EnvironmentalMetrics {
    struct Factor {
        let value: Double
        let rating: String
        let idealRange: ClosedRange<Double>
        let unit: String
    }
    
    let temperature: Factor
    let light: Factor
    let noise: Factor
    let humidity: Factor
}

struct TrendMetrics {
    let sleepDebt: TimeInterval
    let consistencyScore: Double
    let recentSessions: [SleepSession]
}

class SleepInfoAnalyzer {
    private let session: SleepSession
    private let context: NSManagedObjectContext
    private let idealRanges = [
        "temperature": 18.0...22.0,  // Celsius
        "humidity": 30.0...50.0,     // Percentage
        "light": 0.0...5.0,          // Lux
        "noise": 0.0...30.0          // Decibels
    ]
    
    init(session: SleepSession, context: NSManagedObjectContext) {
        self.session = session
        self.context = context
    }
    
    func analyze() -> SleepAnalysis {
        return SleepAnalysis(
            timeMetrics: analyzeTime(),
            efficiencyMetrics: analyzeEfficiency(),
            environmentalMetrics: analyzeEnvironment(),
            trendsMetrics: analyzeTrends()
        )
    }
    
    private func analyzeTime() -> TimeMetrics {
        let comparison = calculateComparison()
        
        return TimeMetrics(
            totalTime: session.timeInSleep,
            timeInBed: session.timeInBed,
            timeToFallAsleep: session.timeToFallAsleep,
            timeAwake: session.timeAwake,
            bedtime: session.startTime ?? Date(),
            wakeTime: session.endTime ?? Date(),
            comparison: comparison
        )
    }
    
    private func analyzeEfficiency() -> EfficiencyMetrics {
        let factorScores = [
            EfficiencyMetrics.EfficiencyFactor(
                name: "Sleep Duration",
                score: calculateDurationScore(),
                icon: "clock.fill",
                color: .blue
            ),
            EfficiencyMetrics.EfficiencyFactor(
                name: "Sleep Continuity",
                score: calculateContinuityScore(),
                icon: "waveform.path.ecg",
                color: .green
            ),
            EfficiencyMetrics.EfficiencyFactor(
                name: "Environment",
                score: session.averageEnvironmentalScore,
                icon: "thermometer",
                color: .orange
            ),
            EfficiencyMetrics.EfficiencyFactor(
                name: "Sleep Timing",
                score: calculateTimingScore(),
                icon: "calendar",
                color: .purple
            )
        ]
        
        return EfficiencyMetrics(
            overall: session.sleepEfficiency,
            trend: determineTrend(for: "efficiency"),
            factorScores: factorScores
        )
    }
    
    private func analyzeEnvironment() -> EnvironmentalMetrics {
        let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading] ?? []
        let lastReading = readings.last
        
        return EnvironmentalMetrics(
            temperature: EnvironmentalMetrics.Factor(
                value: lastReading?.temperature ?? 0,
                rating: ratingFor(value: lastReading?.temperature ?? 0, type: "temperature"),
                idealRange: idealRanges["temperature"]!,
                unit: "°C"
            ),
            light: EnvironmentalMetrics.Factor(
                value: lastReading?.lightLevel ?? 0,
                rating: ratingFor(value: lastReading?.lightLevel ?? 0, type: "light"),
                idealRange: idealRanges["light"]!,
                unit: "lux"
            ),
            noise: EnvironmentalMetrics.Factor(
                value: lastReading?.noiseLevel ?? 0,
                rating: ratingFor(value: lastReading?.noiseLevel ?? 0, type: "noise"),
                idealRange: idealRanges["noise"]!,
                unit: "dB"
            ),
            humidity: EnvironmentalMetrics.Factor(
                value: lastReading?.humidity ?? 0,
                rating: ratingFor(value: lastReading?.humidity ?? 0, type: "humidity"),
                idealRange: idealRanges["humidity"]!,
                unit: "%"
            )
        )
    }
    
    private func analyzeTrends() -> TrendMetrics {
        return TrendMetrics(
            sleepDebt: calculateSleepDebt(),
            consistencyScore: calculateConsistencyScore(),
            recentSessions: fetchRecentSessions()
        )
    }
    
    // MARK: - Scoring Methods
    
    private func calculateDurationScore() -> Double {
        let targetDuration: TimeInterval = 8 * 3600 // 8 hours
        return min(100, (session.timeInSleep / targetDuration) * 100)
    }
    
    private func calculateContinuityScore() -> Double {
        return 100 - ((session.timeAwake / session.timeInBed) * 100)
    }
    
    private func calculateTimingScore() -> Double {
        guard let startTime = session.startTime else { return 0 }
        let hour = Calendar.current.component(.hour, from: startTime)
        
        return switch hour {
        case 21...22: 100.0  // Optimal
        case 20, 23: 80.0    // Good
        case 19, 0: 60.0     // Fair
        default: 40.0        // Poor
        }
    }
    
    private func calculateComparison() -> ComparisonMetrics {
        let recentSessions = fetchRecentSessions()
        let totalDuration = recentSessions.reduce(0) { $0 + $1.timeInSleep }
        let averageDuration = totalDuration / Double(max(1, recentSessions.count))
        
        // Get sleep goal from user preferences
        let request = UserPreferences.fetchRequest()
        let preferences = try? context.fetch(request).first
        let sleepGoal = preferences?.targetSleepDuration ?? (8 * 3600) // Default 8 hours
        
        return ComparisonMetrics(
            averageSleepTime: averageDuration,
            sleepGoal: sleepGoal,
            bedtimeTrend: determineTrend(for: "bedtime"),
            durationTrend: determineTrend(for: "duration")
        )
    }
    
    private func calculateSleepDebt() -> TimeInterval {
        let recentSessions = fetchRecentSessions()
        let targetDuration: TimeInterval = 8 * 3600 // 8 hours
        
        let totalDebt = recentSessions.reduce(0) { debt, session in
            debt + (targetDuration - session.timeInSleep)
        }
        
        return max(0, totalDebt)
    }
    
    private func calculateConsistencyScore() -> Double {
        let sessions = fetchRecentSessions()
        let bedtimes = sessions.compactMap { $0.startTime?.timeIntervalSince1970 }
        
        guard !bedtimes.isEmpty else { return 0 }
        
        let avgBedtime = bedtimes.reduce(0, +) / Double(bedtimes.count)
        let variance = bedtimes.map { pow($0 - avgBedtime, 2) }.reduce(0, +) / Double(bedtimes.count)
        let stdDev = sqrt(variance)
        
        // Convert to percentage (lower variance = higher consistency)
        let maxVariance: TimeInterval = 2 * 3600 // 2 hours variance = 0% consistency
        return 100 * (1 - min(stdDev / maxVariance, 1))
    }
    
    // MARK: - Helper Methods
    
    private func fetchRecentSessions() -> [SleepSession] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "startTime < %@ AND isActive == NO",
            session.startTime! as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: false)
        ]
        request.fetchLimit = 7
        
        return (try? context.fetch(request)) ?? []
    }
    
    private func determineTrend(for metric: String) -> TrendDirection {
        let sessions = fetchRecentSessions()
        guard sessions.count >= 2 else { return .neutral }
        
        switch metric {
        case "efficiency":
            let efficiencies = sessions.map { $0.sleepEfficiency }
            return determineTrendDirection(values: efficiencies)
            
        case "bedtime":
            let bedtimes = sessions.compactMap { $0.startTime?.timeIntervalSince1970 }
            return determineTrendDirection(values: bedtimes)
            
        case "duration":
            let durations = sessions.map { $0.timeInSleep }
            return determineTrendDirection(values: durations)
            
        default:
            return .neutral
        }
    }
    
    private func determineTrendDirection(values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .neutral }
        let difference = values[0] - values[1]
        let threshold = 0.05 * values[1] // 5% change threshold
        
        if abs(difference) < threshold {
            return .neutral
        }
        return difference > 0 ? .up : .down
    }
    
    private func ratingFor(value: Double, type: String) -> String {
        guard let range = idealRanges[type] else { return "Fair" }
        
        // Expanded range for "Good" rating
        let expandedUpperBound = range.upperBound + (range.upperBound - range.lowerBound) * 0.2
        let goodRange = (range.lowerBound - (range.upperBound - range.lowerBound) * 0.2)...expandedUpperBound

        if range.contains(value) {
            return "Optimal"
        } else if goodRange.contains(value) {
            return "Good"
        } else {
            return "Fair"
        }
    }
}
