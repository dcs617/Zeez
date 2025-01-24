import Foundation

/// Handles alarm time calculations and formatting
enum AlarmTimeCalculator {
    /// Calculate the next occurrence of an alarm
    static func nextOccurrence(of time: Date, for alarm: AlarmConfiguration) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour, .minute], from: time)
        components.second = 0
        
        // Get next occurrence of this time
        guard var next = calendar.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime
        ) else { return Date() }
        
        // If we have day preferences, adjust to next valid day
        if let daysData = alarm.daysOfWeek,
           let selectedDays = try? JSONDecoder().decode(Set<Int>.self, from: daysData),
           !selectedDays.isEmpty {
            while !selectedDays.contains(calendar.component(.weekday, from: next)) {
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
                next = calendar.date(
                    bySettingHour: components.hour ?? 0,
                    minute: components.minute ?? 0,
                    second: 0,
                    of: next
                ) ?? next
            }
        }
        
        return next
    }
    
    /// Format the time until the next alarm
    static func timeUntilNextAlarm(_ alarm: AlarmConfiguration) -> String {
        guard let time = alarm.time else { return "" }
        
        let next = nextOccurrence(of: time, for: alarm)
        let difference = next.timeIntervalSince(Date())
        
        let hours = Int(difference) / 3600
        let minutes = Int(difference) / 60 % 60
        
        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
}