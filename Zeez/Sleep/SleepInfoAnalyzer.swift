import Foundation
import CoreData
import os.log

struct SleepAnalysis {
    let timeMetrics: TimeMetrics
    let basicMetrics: BasicMetrics
}

struct TimeMetrics {
    let totalTime: TimeInterval
    let timeInBed: TimeInterval
    let bedtime: Date
    let wakeTime: Date
    let sleepGoal: TimeInterval
}

struct BasicMetrics {
    let efficiency: Double
    let sleepDebt: TimeInterval
    let consistencyScore: Double
}

class SleepInfoAnalyzer {
    private let session: SleepSession
    private let context: NSManagedObjectContext
    
    init(session: SleepSession, context: NSManagedObjectContext) {
        self.session = session
        self.context = context
    }
    
    func analyze() -> SleepAnalysis {
        return SleepAnalysis(
            timeMetrics: analyzeTime(),
            basicMetrics: analyzeBasicMetrics()
        )
    }
    
    private func analyzeTime() -> TimeMetrics {
        let sleepGoal = getSleepGoal()
        
        return TimeMetrics(
            totalTime: calculateTotalSleepTime(),
            timeInBed: calculateTimeInBed(),
            bedtime: session.startTime ?? Date(),
            wakeTime: session.endTime ?? Date(),
            sleepGoal: sleepGoal
        )
    }
    
    private func analyzeBasicMetrics() -> BasicMetrics {
        return BasicMetrics(
            efficiency: calculateEfficiency(),
            sleepDebt: calculateSleepDebt(),
            consistencyScore: calculateConsistencyScore()
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func calculateTotalSleepTime() -> TimeInterval {
        guard let startTime = session.startTime,
              let endTime = session.endTime else { return 0 }
        return endTime.timeIntervalSince(startTime)
    }
    
    private func calculateTimeInBed() -> TimeInterval {
        return calculateTotalSleepTime() // Simplified - same as total time
    }
    
    private func calculateEfficiency() -> Double {
        let totalTime = calculateTotalSleepTime()
        guard totalTime > 0 else { return 0 }
        
        // Basic efficiency based on sleep duration vs optimal range
        let hours = totalTime / 3600
        if hours >= 7 && hours <= 9 {
            return 100.0
        } else if hours < 7 {
            return (hours / 7) * 100
        } else {
            return max(0, 100 - ((hours - 9) * 10))
        }
    }
    
    private func calculateSleepDebt() -> TimeInterval {
        let sleepGoal = getSleepGoal()
        let actualSleep = calculateTotalSleepTime()
        return max(0, sleepGoal - actualSleep)
    }
    
    private func calculateConsistencyScore() -> Double {
        // Simplified consistency - return fixed value for now
        return 75.0 // Will be enhanced in Phase 2
    }
    
    private func getSleepGoal() -> TimeInterval {
        let request = UserPreferences.fetchRequest()
        if let preferences = try? context.fetch(request).first {
            return preferences.targetSleepDuration
        }
        return 8 * 3600 // Default 8 hours
    }
}
