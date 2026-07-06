import CoreData
import Foundation
import os.log

class UserPatternAnalyzer {
    private let persistenceController = PersistenceController.shared
    private let calendar = Calendar.current
    
    struct UserPattern {
        let averageBedtime: Date
        let averageWakeTime: Date
        let typicalSleepDuration: TimeInterval
        let preferredUpdateWindows: [DateInterval]
        let activeHours: [Int] // Hours of day when user is typically active
    }
    
    private var cachedPattern: UserPattern?
    private var lastAnalysis: Date?
    private let analysisValidityPeriod: TimeInterval = 86400 * 7 // 1 week
    
    func getOptimalSleepUpdateTime() -> Date? {
        let pattern = getUserPattern()
        
        // Schedule updates during typical wake hours, but not immediately upon waking
        let wakeHour = calendar.component(.hour, from: pattern.averageWakeTime)
        let optimalHour = (wakeHour + 2) % 24 // 2 hours after typical wake time
        
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = optimalHour
        dateComponents.minute = 0
        
        guard let optimalTime = calendar.date(from: dateComponents) else {
            return Date(timeIntervalSinceNow: 3600) // 1 hour fallback
        }
        
        // If the optimal time has passed today, schedule for tomorrow
        if optimalTime <= Date() {
            return calendar.date(byAdding: .day, value: 1, to: optimalTime)
        }
        
        return optimalTime
    }
    
    func getUserPattern() -> UserPattern {
        // Return cached pattern if still valid
        if let cached = cachedPattern,
           let lastAnalysis = lastAnalysis,
           Date().timeIntervalSince(lastAnalysis) < analysisValidityPeriod {
            return cached
        }
        
        // Analyze recent sleep patterns
        let pattern = analyzeUserPatterns()
        cachedPattern = pattern
        lastAnalysis = Date()
        
        ZeezLogger.info(ZeezLogger.background, "Updated user pattern analysis")
        return pattern
    }
    
    private func analyzeUserPatterns() -> UserPattern {
        let context = persistenceController.container.viewContext
        
        // Fetch recent sleep sessions (last 30 days)
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let fetchRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "endTime >= %@ AND isActive == NO AND startTime != nil AND endTime != nil",
            thirtyDaysAgo as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "endTime", ascending: false)]
        fetchRequest.fetchLimit = 30 // Last 30 sessions
        
        do {
            let sessions = try context.fetch(fetchRequest)
            return calculatePatternsFromSessions(sessions)
        } catch {
            ZeezLogger.error(ZeezLogger.background, "Failed to fetch sleep sessions for pattern analysis", error: error)
            return getDefaultPattern()
        }
    }
    
    private func calculatePatternsFromSessions(_ sessions: [SleepSession]) -> UserPattern {
        guard !sessions.isEmpty else {
            return getDefaultPattern()
        }
        
        var bedtimes: [Date] = []
        var wakeTimes: [Date] = []
        var durations: [TimeInterval] = []
        var activeHours: [Int] = []
        
        for session in sessions {
            guard let startTime = session.startTime,
                  let endTime = session.endTime else {
                continue
            }
            
            bedtimes.append(startTime)
            wakeTimes.append(endTime)
            durations.append(endTime.timeIntervalSince(startTime))
            
            // Analyze active hours (hours when user is awake)
            let wakeHour = calendar.component(.hour, from: endTime)
            let bedHour = calendar.component(.hour, from: startTime)
            
            // Add hours between wake and bedtime as active hours
            var hour = wakeHour
            while hour != bedHour {
                activeHours.append(hour)
                hour = (hour + 1) % 24
            }
        }
        
        let averageBedtime = calculateAverageTime(from: bedtimes)
        let averageWakeTime = calculateAverageTime(from: wakeTimes)
        let averageDuration = durations.reduce(0, +) / Double(durations.count)
        
        // Calculate preferred update windows (times when user is typically active)
        let preferredWindows = calculatePreferredUpdateWindows(from: activeHours)
        let uniqueActiveHours = Array(Set(activeHours)).sorted()
        
        return UserPattern(
            averageBedtime: averageBedtime,
            averageWakeTime: averageWakeTime,
            typicalSleepDuration: averageDuration,
            preferredUpdateWindows: preferredWindows,
            activeHours: uniqueActiveHours
        )
    }
    
    private func calculateAverageTime(from dates: [Date]) -> Date {
        guard !dates.isEmpty else {
            return Date()
        }
        
        // Convert times to minutes since midnight, then average
        let minutesFromMidnight = dates.map { date in
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            return hour * 60 + minute
        }
        
        let averageMinutes = minutesFromMidnight.reduce(0, +) / minutesFromMidnight.count
        let averageHour = averageMinutes / 60
        let averageMinute = averageMinutes % 60
        
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = averageHour
        dateComponents.minute = averageMinute
        
        return calendar.date(from: dateComponents) ?? Date()
    }
    
    private func calculatePreferredUpdateWindows(from activeHours: [Int]) -> [DateInterval] {
        guard !activeHours.isEmpty else {
            return [getDefaultUpdateWindow()]
        }
        
        // Group consecutive active hours into windows
        let uniqueHours = Array(Set(activeHours)).sorted()
        var windows: [DateInterval] = []
        var currentWindowStart: Int?
        var currentWindowEnd: Int?
        
        for hour in uniqueHours {
            if currentWindowStart == nil {
                currentWindowStart = hour
                currentWindowEnd = hour
            } else if hour == currentWindowEnd! + 1 {
                currentWindowEnd = hour
            } else {
                // End current window and start new one
                if let start = currentWindowStart, let end = currentWindowEnd {
                    windows.append(createDateInterval(startHour: start, endHour: end + 1))
                }
                currentWindowStart = hour
                currentWindowEnd = hour
            }
        }
        
        // Add final window
        if let start = currentWindowStart, let end = currentWindowEnd {
            windows.append(createDateInterval(startHour: start, endHour: end + 1))
        }
        
        return windows.isEmpty ? [getDefaultUpdateWindow()] : windows
    }
    
    private func createDateInterval(startHour: Int, endHour: Int) -> DateInterval {
        let today = Date()
        var startComponents = calendar.dateComponents([.year, .month, .day], from: today)
        startComponents.hour = startHour
        startComponents.minute = 0
        
        var endComponents = startComponents
        endComponents.hour = endHour
        
        let startDate = calendar.date(from: startComponents) ?? today
        let endDate = calendar.date(from: endComponents) ?? calendar.date(byAdding: .hour, value: 1, to: startDate)!
        
        return DateInterval(start: startDate, end: endDate)
    }
    
    private func getDefaultPattern() -> UserPattern {
        // Default pattern for users without sufficient data
        let defaultBedtime = createTimeToday(hour: 23, minute: 0) // 11 PM
        let defaultWakeTime = createTimeToday(hour: 7, minute: 0)  // 7 AM
        let defaultDuration: TimeInterval = 8 * 3600 // 8 hours
        
        return UserPattern(
            averageBedtime: defaultBedtime,
            averageWakeTime: defaultWakeTime,
            typicalSleepDuration: defaultDuration,
            preferredUpdateWindows: [getDefaultUpdateWindow()],
            activeHours: [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22] // 7 AM - 10 PM
        )
    }
    
    private func getDefaultUpdateWindow() -> DateInterval {
        let startTime = createTimeToday(hour: 9, minute: 0)  // 9 AM
        let endTime = createTimeToday(hour: 22, minute: 0)   // 10 PM
        return DateInterval(start: startTime, end: endTime)
    }
    
    private func createTimeToday(hour: Int, minute: Int) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }
    
    func invalidateCache() {
        cachedPattern = nil
        lastAnalysis = nil
    }
}