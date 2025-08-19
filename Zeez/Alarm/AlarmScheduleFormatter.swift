import Foundation
import os.log

/// Formats alarm schedule days into readable text
enum AlarmScheduleFormatter {
    static func format(_ days: Set<Int>) -> String {
        if days.count == 7 {
            return "Every day"
        } else if days.count == 5 && days.isSubset(of: Set(2...6)) {
            return "Weekdays"
        } else if days.count == 2 && days.isSubset(of: Set([1, 7])) {
            return "Weekends"
        } else {
            return formatCustomDays(days)
        }
    }
    
    private static func formatCustomDays(_ days: Set<Int>) -> String {
        let weekdays = Calendar.current.shortWeekdaySymbols
        let dayNames = days.sorted().map { weekdays[$0 - 1] }
        return dayNames.joined(separator: ", ")
    }
}
