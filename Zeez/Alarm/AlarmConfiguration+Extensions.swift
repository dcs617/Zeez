import Foundation
import CoreData
import os.log

// MARK: - Heavy Sleeper Mode Support
extension AlarmConfiguration {
    
    // heavySleeperMode is a real @NSManaged property (see
    // AlarmConfiguration+CoreDataProperties.swift) — the attribute has always
    // existed in the model; only the generated property was missing. Legacy
    // UserDefaults values are migrated once at launch by AlarmDataMigrationHelper.

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
            ZeezLogger.info(ZeezLogger.alarm, "Snooze duration updated to \(minutes) minutes for alarm \(self.id?.uuidString ?? "Unknown")")
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "Failed to save snooze duration", error: error)
        }
    }
}
