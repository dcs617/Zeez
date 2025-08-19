import Foundation
import os.log

enum AlarmSortOption: String, CaseIterable {
    case time = "Time"
    case dayOfWeek = "Days"
    case repeating = "Repeating"
    
    func sortAlarms(_ alarms: [AlarmConfiguration]) -> [AlarmConfiguration] {
        switch self {
        case .time:
            return alarms.sorted { alarm1, alarm2 in
                guard let time1 = alarm1.time,
                      let time2 = alarm2.time else { return false }
                return time1 < time2
            }
            
        case .dayOfWeek:
            return alarms.sorted { alarm1, alarm2 in
                let days1 = alarm1.decodedDaysOfWeek
                let days2 = alarm2.decodedDaysOfWeek
                
                // Every day alarms come first
                if days1.count == 7 && days2.count != 7 { return true }
                if days2.count == 7 && days1.count != 7 { return false }
                
                // Compare earliest day of the week
                let firstDay1 = days1.min() ?? 8
                let firstDay2 = days2.min() ?? 8
                return firstDay1 < firstDay2
            }
            
        case .repeating:
            return alarms.sorted { alarm1, alarm2 in
                let days1 = alarm1.decodedDaysOfWeek
                let days2 = alarm2.decodedDaysOfWeek
                
                if days1.isEmpty && !days2.isEmpty { return false }
                if !days1.isEmpty && days2.isEmpty { return true }
                return true
            }
        }
    }
}

extension AlarmConfiguration {
    var decodedDaysOfWeek: Set<Int> {
        guard let daysData = daysOfWeek,
              let days = try? JSONDecoder().decode(Set<Int>.self, from: daysData) else {
            return []
        }
        return days
    }
}
