import Foundation

enum DebtTrend {
    case improving, stable, worsening
}

struct RecoveryPlan {
    enum Severity {
        case mild, moderate, severe
    }
    
    let recommendedAction: String
    let timeToRecover: String
    let severity: Severity
}

struct SleepDebtMetrics {
    let weeklyDebt: TimeInterval
    let monthlyDebt: TimeInterval
    let debtTrend: DebtTrend
    let recoveryPlan: RecoveryPlan
}