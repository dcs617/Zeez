import Foundation
import os.log

/// Contains recommendations for optimal sleep
struct SleepRecommendations {
    let recommendedSleepDuration: ClosedRange<Double>
    let suggestedBedtime: Date
    let suggestedWakeTime: Date
    let consistencyScore: Double
    let qualityTips: [String]
    let scheduleAdjustments: [String]
}

/// Represents analyzed sleep patterns
struct SleepPatterns {
    let averageDuration: TimeInterval
    let averageBedtime: Date?
    let averageWakeTime: Date?
    let consistencyScore: Double
    let averageQuality: Double
    let commonIssues: [SleepIssue]
}

/// Represents a sleep-related issue with recommendations
struct SleepIssue {
    enum IssueType {
        case lateBedtime
        case irregularSchedule
        case poorEnvironment
        case poorQuality
        case insufficientDuration
    }
    
    let type: IssueType
    let description: String
    let recommendation: String
}
