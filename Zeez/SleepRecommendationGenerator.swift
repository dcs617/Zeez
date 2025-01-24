import Foundation

struct SleepRecommendationGenerator {
    static func calculateOptimalSchedule(
        patterns: SleepPatterns,
        targetDuration: Double
    ) -> (bedtime: Date, wakeTime: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        // Use average bedtime as base if available, otherwise default to 22:00
        let baseBedtime = patterns.averageBedtime ?? calendar.date(
            bySettingHour: 22,
            minute: 0,
            second: 0,
            of: now
        ) ?? now
        
        // Calculate wake time based on target duration
        let wakeTime = calendar.date(
            byAdding: .second,
            value: Int(targetDuration),
            to: baseBedtime
        ) ?? now
        
        // Adjust for historical patterns
        let adjustedBedtime = adjustTimeForConsistency(
            baseBedtime,
            consistency: patterns.consistencyScore
        )
        
        return (bedtime: adjustedBedtime, wakeTime: wakeTime)
    }
    
    static func generateQualityTips(from patterns: SleepPatterns) -> [String] {
        var tips: [String] = []
        
        // Add tips based on sleep quality
        if patterns.averageQuality < 70 {
            tips.append("Consider making your room darker and quieter")
            tips.append("Maintain a consistent bedtime routine")
        }
        
        // Add tips based on consistency
        if patterns.consistencyScore < 80 {
            tips.append("Try to go to bed at the same time each night")
            tips.append("Set a regular wake-up time, even on weekends")
        }
        
        // Add tips based on common issues
        for issue in patterns.commonIssues {
            tips.append(recommendationFor(issue))
        }
        
        return Array(Set(tips))  // Remove duplicates
    }
    
    static func generateScheduleAdjustments(from patterns: SleepPatterns) -> [String] {
        var adjustments: [String] = []
        
        // Check sleep timing consistency
        if patterns.consistencyScore < 70 {
            let variance = 100 - patterns.consistencyScore
            let minutes = Int(variance * 0.6)  // Convert score to approximate minutes
            adjustments.append("Your bedtime varies by about \(minutes) minutes. Try to be more consistent.")
        }
        
        // Check for late bedtimes
        if let avgBedtime = patterns.averageBedtime {
            let hour = Calendar.current.component(.hour, from: avgBedtime)
            if hour >= 23 || hour < 5 {
                adjustments.append("Your average bedtime is quite late. Consider going to bed earlier.")
            }
        }
        
        // Add duration-based adjustments
        let durationInHours = patterns.averageDuration / 3600
        if durationInHours < 7 {
            adjustments.append("You're averaging \(String(format: "%.1f", durationInHours)) hours of sleep. Aim for 7-9 hours.")
        }
        
        return adjustments
    }
    
    // MARK: - Private Helpers
    
    private static func adjustTimeForConsistency(_ time: Date, consistency: Double) -> Date {
        // If consistency is high, keep the time as is
        if consistency > 80 {
            return time
        }
        
        // For lower consistency, suggest a slightly earlier bedtime
        let adjustment = (80 - consistency) * 60  // seconds to adjust
        return time.addingTimeInterval(-adjustment)
    }
    
    private static func recommendationFor(_ issue: SleepIssue) -> String {
        switch issue.type {
        case .lateBedtime:
            return "Try moving your bedtime 15 minutes earlier each week"
        case .irregularSchedule:
            return "Set an evening reminder to help maintain your sleep schedule"
        case .poorEnvironment:
            return "Consider using a sleep mask and earplugs for better sleep quality"
        case .poorQuality:
            return "Review your evening routine and bedroom environment"
        case .insufficientDuration:
            return "Plan for at least 7 hours of sleep each night"
        }
    }
}


