import Foundation
import os.log

/// Represents time ranges specifically for sleep trend analysis and visualization
enum SleepTrendRange: Int, CaseIterable, Identifiable {
    case week = 0        // Last 7 days
    case month = 1       // Last month
    case threeMonths = 2 // Last 3 months
    
    var id: Int { rawValue }
    
    var description: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        }
    }
    
    var dateInterval: DateInterval {
        let now = Date()
        let start: Date
        
        switch self {
        case .week:
            start = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            start = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        case .threeMonths:
            start = Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now
        }
        
        return DateInterval(start: start, end: now)
    }
}
