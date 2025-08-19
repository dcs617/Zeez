import Foundation
import os.log

enum DebtTrend {
    case improving, stable, worsening
}

struct RecoveryPlan {
    let recommendedAction: String
    let timeToRecover: String
    let severity: DebtSeverity
}

struct SleepDebtMetrics {
    let weeklyDebt: TimeInterval
    let monthlyDebt: TimeInterval
    let debtTrend: DebtTrend
    let recoveryPlan: RecoveryPlan
}
