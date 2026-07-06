import Foundation
import CoreData
import os.log

/// Helper for migrating alarm data and ensuring data integrity
class AlarmDataMigrationHelper {
    
    /// Migrate any UserDefaults heavy sleeper settings to Core Data
    /// Call this once after adding the heavySleeperMode attribute to Core Data
    static func migrateHeavySleeperSettings(context: NSManagedObjectContext) {
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        
        do {
            let alarms = try context.fetch(request)
            var migratedCount = 0
            
            for alarm in alarms {
                guard let alarmId = alarm.id?.uuidString else { continue }
                let userDefaultsKey = "heavySleeperMode_\(alarmId)"
                
                // Check if UserDefaults has a value for this alarm
                if UserDefaults.standard.object(forKey: userDefaultsKey) != nil {
                    let userDefaultsValue = UserDefaults.standard.bool(forKey: userDefaultsKey)
                    
                    // Only migrate if Core Data doesn't already have a value
                    if alarm.value(forKey: "heavySleeperMode") == nil {
                        alarm.setValue(userDefaultsValue, forKey: "heavySleeperMode")
                        migratedCount += 1
                        
                        ZeezLogger.info(ZeezLogger.alarm, "Migrated heavy sleeper mode (\(userDefaultsValue)) for alarm: \(alarm.name ?? "Unknown")")
                    }
                    
                    // Clean up UserDefaults
                    UserDefaults.standard.removeObject(forKey: userDefaultsKey)
                }
            }
            
            if migratedCount > 0 {
                try context.save()
                ZeezLogger.info(ZeezLogger.alarm, "✅ Successfully migrated \(migratedCount) heavy sleeper settings to Core Data")
            } else {
                ZeezLogger.info(ZeezLogger.alarm, "No heavy sleeper settings to migrate")
            }
            
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "Failed to migrate heavy sleeper settings", error: error)
        }
    }
    
    /// Validate alarm configurations and fix any inconsistencies
    static func validateAlarmConfigurations(context: NSManagedObjectContext) {
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        
        do {
            let alarms = try context.fetch(request)
            var fixedCount = 0
            
            for alarm in alarms {
                var needsSave = false
                
                // Ensure all alarms have UUIDs
                if alarm.id == nil {
                    alarm.id = UUID()
                    needsSave = true
                    ZeezLogger.info(ZeezLogger.alarm, "Added missing UUID to alarm: \(alarm.name ?? "Unknown")")
                }
                
                // Ensure all alarms have creation dates
                if alarm.createdAt == nil {
                    alarm.createdAt = Date()
                    needsSave = true
                }
                
                // Ensure modification dates are set
                if alarm.modifiedAt == nil {
                    alarm.modifiedAt = alarm.createdAt ?? Date()
                    needsSave = true
                }
                
                // Validate heavy sleeper mode attribute exists and has a default value
                if alarm.value(forKey: "heavySleeperMode") == nil {
                    alarm.setValue(false, forKey: "heavySleeperMode")
                    needsSave = true
                }
                
                if needsSave {
                    fixedCount += 1
                }
            }
            
            if fixedCount > 0 {
                try context.save()
                ZeezLogger.info(ZeezLogger.alarm, "✅ Fixed \(fixedCount) alarm configurations")
            }
            
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "Failed to validate alarm configurations", error: error)
        }
    }
    
    /// Run all migration and validation tasks
    /// Call this once during app initialization after Core Data is loaded
    static func performMigrationAndValidation(context: NSManagedObjectContext) {
        ZeezLogger.info(ZeezLogger.alarm, "🔄 Starting alarm data migration and validation...")
        
        migrateHeavySleeperSettings(context: context)
        validateAlarmConfigurations(context: context)
        
        ZeezLogger.info(ZeezLogger.alarm, "✅ Alarm data migration and validation completed")
    }
}