import Foundation
import CoreData

// MARK: - Shared Data Models for Watch Communication

/// Sleep summary data optimized for watch display
struct WatchSleepSummary: Codable {
    let lastNightDuration: TimeInterval
    let qualityScore: Double
    let bedTime: Date?
    let wakeTime: Date?
    let isDataAvailable: Bool
    let isQualityScoreAvailable: Bool
    
    init(duration: TimeInterval = 0, quality: Double = 0, qualityAvailable: Bool = false, bedTime: Date? = nil, wakeTime: Date? = nil) {
        self.lastNightDuration = duration
        self.qualityScore = quality
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.isDataAvailable = duration > 0
        self.isQualityScoreAvailable = qualityAvailable
    }
}

/// Alarm status for watch display
struct WatchAlarmStatus: Codable {
    let nextAlarmTime: Date?
    let isEnabled: Bool
    let smartWakeEnabled: Bool
    let smartWakeWindow: Int
    let alarmName: String
    
    init(time: Date? = nil, enabled: Bool = false, smartWake: Bool = false, window: Int = 30, name: String = "Alarm") {
        self.nextAlarmTime = time
        self.isEnabled = enabled
        self.smartWakeEnabled = smartWake
        self.smartWakeWindow = window
        self.alarmName = name
    }
}

/// Watch sync message types
enum WatchMessageType: String, CaseIterable {
    case sleepSummary = "sleepSummary"
    case alarmStatus = "alarmStatus"
    case wakePattern = "wakePattern"
    case stopPattern = "stopPattern"
    case acknowledge = "acknowledge"
    case snooze = "snooze"
    case requestData = "requestData"
}

/// Haptic pattern types for wake-up progression
enum HapticPattern: String, CaseIterable, Codable {
    case gentle = "gentle"
    case moderate = "moderate"
    case strong = "strong"
}

/// Wake pattern data for watch haptics
struct WakePatternData: Codable {
    let pattern: HapticPattern
    let intensity: Double
    let duration: TimeInterval
    
    init(pattern: HapticPattern, intensity: Double, duration: TimeInterval = 30) {
        self.pattern = pattern
        self.intensity = intensity
        self.duration = duration
    }
}

// MARK: - Enhanced Data Model Extensions

extension WatchSleepSummary {
    /// Initialize from Core Data sleep session
    init(from coreDataSession: SleepSession) {
        guard let startTime = coreDataSession.startTime,
              let endTime = coreDataSession.endTime,
              let duration = coreDataSession.derivedSleepMetrics.recordedSessionInterval.value else {
            self.init()
            return
        }

        self.init(
            duration: duration,
            quality: coreDataSession.qualityScore,
            qualityAvailable: coreDataSession.hasDisplayableScore,
            bedTime: startTime,
            wakeTime: endTime
        )
    }
    
    /// Formatted duration string (e.g., "7h 30m")
    var formattedDuration: String {
        let hours = Int(lastNightDuration) / 3600
        let minutes = Int(lastNightDuration.truncatingRemainder(dividingBy: 3600)) / 60
        return "\(hours)h \(minutes)m"
    }
    
    /// Human-readable quality description
    var qualityDescription: String {
        guard isQualityScoreAvailable else { return "Not Available" }
        switch qualityScore {
        case 90...100: return "Excellent"
        case 80..<90: return "Good"
        case 70..<80: return "Fair"
        case 60..<70: return "Poor"
        default: return "Very Poor"
        }
    }
    
    /// Quality color indicator for UI
    var qualityColor: String {
        guard isQualityScoreAvailable else { return "gray" }
        switch qualityScore {
        case 90...100: return "green"
        case 80..<90: return "blue"
        case 70..<80: return "yellow"
        case 60..<70: return "orange"
        default: return "red"
        }
    }
    
    /// Short summary for complications
    var shortSummary: String {
        return "\(formattedDuration) • \(qualityDescription)"
    }
}

extension WatchAlarmStatus {
    /// Time until next alarm in seconds
    var timeUntilAlarm: TimeInterval? {
        guard let nextTime = nextAlarmTime else { return nil }
        let now = Date()
        let timeInterval = nextTime.timeIntervalSince(now)
        return timeInterval > 0 ? timeInterval : nil
    }
    
    /// Whether alarm is upcoming (within 12 hours)
    var isUpcoming: Bool {
        guard let timeUntil = timeUntilAlarm else { return false }
        return timeUntil <= 12 * 3600 // Within 12 hours
    }
    
    /// Formatted time until alarm (e.g., "2h 15m" or "45m")
    var formattedTimeUntil: String? {
        guard let timeUntil = timeUntilAlarm else { return nil }
        
        let hours = Int(timeUntil) / 3600
        let minutes = Int(timeUntil.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Status description for display
    var statusDescription: String {
        guard isEnabled else { return "Off" }
        
        if let timeString = formattedTimeUntil {
            return "in \(timeString)"
        } else {
            return "No upcoming alarm"
        }
    }
    
    /// Short status for complications
    var shortStatus: String {
        guard isEnabled else { return "Off" }
        return formattedTimeUntil ?? "None"
    }
    
    /// Whether smart wake is active and functional
    var isSmartWakeActive: Bool {
        return isEnabled && smartWakeEnabled && isUpcoming
    }
}
