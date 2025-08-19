import Foundation
import os.log

/// Represents time ranges for general sleep statistics and analytics
enum SleepStatsRange: Int, CaseIterable, Identifiable {
    case days = 0     // Last 7 days
    case weeks = 1    // Last 4 weeks
    case months = 2   // Last 3 months
    case all = 3      // All time
    
    var id: Int { rawValue }
    
    var description: String {
        switch self {
        case .days: return "Days"
        case .weeks: return "Weeks"
        case .months: return "Months"
        case .all: return "All"
        }
    }
    
    var dateInterval: DateInterval {
        let now = Date()
        let start: Date
        
        switch self {
        case .days:
            start = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        case .weeks:
            start = Calendar.current.date(byAdding: .day, value: -28, to: now) ?? now
        case .months:
            start = Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now
        case .all:
            start = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        }
        
        return DateInterval(start: start, end: now)
    }
}
