import Foundation
import CoreData
import UserNotifications
import os.log

// MARK: - Heavy Sleeper Mode Support
extension AlarmConfiguration {
    
    /// Heavy sleeper mode property using Core Data
    /// Note: After adding the heavySleeperMode Boolean attribute to Core Data, 
    /// this will use the native Core Data property
    var heavySleeperModeEnabled: Bool {
        get {
            // Try to use Core Data attribute first, fall back to UserDefaults for migration
            if let coreDataValue = self.value(forKey: "heavySleeperMode") as? Bool {
                return coreDataValue
            }
            
            // Use UserDefaults as fallback (or primary if Core Data attribute doesn't exist)
            guard let alarmId = self.id?.uuidString else { return false }
            return UserDefaults.standard.bool(forKey: "heavySleeperMode_\(alarmId)")
        }
        set {
            // Try to set Core Data value first
            self.setValue(newValue, forKey: "heavySleeperMode")
            
            // If successful, clean up UserDefaults
            if let alarmId = self.id?.uuidString {
                UserDefaults.standard.removeObject(forKey: "heavySleeperMode_\(alarmId)")
            }
            
            // Update the alarm's modification date
            self.modifiedAt = Date()
            
            // Log the change
            ZeezLogger.info(ZeezLogger.alarm, "Heavy sleeper mode \(newValue ? "enabled" : "disabled") for alarm: \(self.name ?? "Unknown")")
        }
    }
    
    /// Convenience property that matches the old name for backward compatibility
    var heavySleeperMode: Bool {
        get { heavySleeperModeEnabled }
        set { heavySleeperModeEnabled = newValue }
    }
    
    /// Convenience property for getting the appropriate cadence based on heavy sleeper mode
    var followUpCadence: TimeInterval {
        return AlarmNotificationUtils.getCadence(isHeavySleeper: heavySleeperMode)
    }
    
    /// Convenience property for getting the appropriate max follow-ups based on heavy sleeper mode
    var maxFollowUps: Int {
        return AlarmNotificationUtils.getMaxFollowUps(isHeavySleeper: heavySleeperMode)
    }
    
    /// Gets the snooze duration in minutes, with fallback to default if not set
    var snoozeDurationMinutes: Int {
        let duration = Int(snoozeDuration) // snoozeDuration is stored as Int16 in Core Data
        return duration > 0 ? duration : AlarmNotificationUtils.defaultSnoozeMinutes
    }
    
    /// Sets the snooze duration and saves
    func setSnoozeDuration(minutes: Int) {
        self.snoozeDuration = Int16(minutes)
        self.modifiedAt = Date()
        
        do {
            try self.managedObjectContext?.save()
            ZeezLogger.info(ZeezLogger.alarm, "Snooze duration updated to \(minutes) minutes for alarm: \(self.name ?? "Unknown")")
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "Failed to save snooze duration", error: error)
        }
    }
}

// MARK: - Alarm Validation
extension AlarmConfiguration {
    
    /// Validates that the alarm is properly configured
    var isValidForScheduling: Bool {
        guard enabled,
              time != nil,
              let daysData = daysOfWeek,
              let selectedDays = try? JSONDecoder().decode(Set<Int>.self, from: daysData),
              !selectedDays.isEmpty else {
            return false
        }
        return true
    }
    
    /// Returns a user-friendly description of when this alarm will ring
    var scheduleDescription: String {
        guard let time = time,
              let daysData = daysOfWeek,
              let selectedDays = try? JSONDecoder().decode(Set<Int>.self, from: daysData) else {
            return "Not configured"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: time)
        
        let dayNames: [String] = selectedDays.sorted().compactMap { dayIndex in
            guard dayIndex >= 1 && dayIndex <= 7 else { return nil }
            return Calendar.current.shortWeekdaySymbols[dayIndex - 1]
        }
        
        let daysString = dayNames.joined(separator: ", ")
        return "\(timeString) on \(daysString)"
    }
}

// MARK: - Sound Configuration
extension AlarmConfiguration {
    
    /// Gets the notification sound for this alarm
    var notificationSound: UNNotificationSound? {
        if vibrationOnly {
            return nil
        }
        
        let soundName = alarmSound ?? "Alarm_Classic.caf"
        return AlarmScheduler.shared.getAlarmSound(for: soundName)
    }
    
    /// Gets the long-form sound name for continuous playback
    var longSoundName: String {
        // You can customize this based on the alarm's sound selection
        return AlarmNotificationUtils.longInAppBundledName
    }
}

// MARK: - Smart Wake Integration  
extension AlarmConfiguration {
    
    /// Calculates the actual trigger time considering smart wake window
    func triggerTime(isSmartWake: Bool) -> Date? {
        guard let baseTime = time else { return nil }
        
        if isSmartWake && smartWakeEnabled {
            return baseTime.addingTimeInterval(-Double(smartWakeWindow) * 60)
        } else {
            return baseTime
        }
    }
}