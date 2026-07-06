import UserNotifications
import CoreData
import os.log

/// Small helpers for follow-ups and snooze.
enum AlarmNotificationUtils {
    /// Default = 60s; you can switch to 31s for "Heavy Sleeper" mode.
    static var defaultCadenceSeconds: TimeInterval = 60
    /// Heavy sleeper cadence for more frequent follow-ups
    static var heavySleeperCadenceSeconds: TimeInterval = 31
    /// Safety under global 64 cap (leave headroom for other requests).
    static var maxFollowUps: Int = 12
    /// Heavy sleeper gets more follow-ups
    static var maxHeavySleeperFollowUps: Int = 20
    /// Default snooze length.
    static var defaultSnoozeMinutes: Int = 9
    /// Long, in-app-only bundled loop file (place in your bundle).
    static var longInAppBundledName: String = "Zeez_Long_Default"
    
    /// Get cadence based on heavy sleeper setting
    static func getCadence(isHeavySleeper: Bool) -> TimeInterval {
        return isHeavySleeper ? heavySleeperCadenceSeconds : defaultCadenceSeconds
    }
    
    /// Get max follow-ups based on heavy sleeper setting
    static func getMaxFollowUps(isHeavySleeper: Bool) -> Int {
        return isHeavySleeper ? maxHeavySleeperFollowUps : maxFollowUps
    }

    static func scheduleSnooze(for alarmId: String, minutes: Int = defaultSnoozeMinutes) {
        // First, cancel any pending follow-ups for this alarm
        cancelPendingFollowUps(for: alarmId)
        
        // Get the original alarm to preserve its settings
        // "id" is a UUID attribute; SQLite stores cannot evaluate uuidString keypaths in predicates
        guard let uuid = UUID(uuidString: alarmId) else {
            scheduleBasicSnooze(for: alarmId, minutes: minutes)
            return
        }
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            if let alarm = try context.fetch(request).first {
                // Use the alarm's custom snooze duration instead of the default
                let customMinutes = alarm.snoozeDurationMinutes
                scheduleSnoozeWithAlarmSettings(alarm: alarm, minutes: customMinutes)
            } else {
                // Fallback: create basic snooze notification
                scheduleBasicSnooze(for: alarmId, minutes: minutes)
            }
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "Error fetching alarm for snooze", error: error)
            scheduleBasicSnooze(for: alarmId, minutes: minutes)
        }
    }
    
    private static func scheduleSnoozeWithAlarmSettings(alarm: AlarmConfiguration, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = alarm.name ?? "Alarm"
        content.body = "Snooze time's up!"
        content.categoryIdentifier = AlarmNotificationRegistrar.categoryId
        content.userInfo = [
            "alarmID": alarm.id?.uuidString ?? "",
            "type": "main",  // Important: This makes it trigger follow-ups!
            "isSnooze": true
        ]
        
        // Use dynamic interruption level and sound
        getInterruptionLevel { interruptionLevel in
            content.interruptionLevel = interruptionLevel
            
            // Use the alarm's configured sound instead of default
            let alarmSound = alarm.alarmSound ?? "Alarm_Classic.caf"
            let vibrationOnly = alarm.vibrationOnly
            
            if vibrationOnly {
                content.sound = nil
            } else {
                content.sound = getSnoozeSound(alarmSound: alarmSound, criticalEnabled: interruptionLevel == .critical)
            }
                
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
                let timestamp = Int(Date().timeIntervalSince1970)
                let id = "snooze-\(alarm.id?.uuidString ?? "unknown")-\(timestamp)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        ZeezLogger.error(ZeezLogger.alarm, "Failed to schedule proper snooze alarm", error: error)
                    } else {
                        ZeezLogger.info(ZeezLogger.alarm, "💤 Snooze scheduled for \(minutes) minutes with sound: \(alarmSound)")
                    }
                }
        }
    }
    
    private static func scheduleBasicSnooze(for alarmId: String, minutes: Int) {
        // Fallback when alarm not found - still creates proper alarm notification
        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        content.body = "Snooze time's up!"
        content.categoryIdentifier = AlarmNotificationRegistrar.categoryId
        content.userInfo = [
            "alarmID": alarmId,
            "type": "main",  // This triggers follow-ups
            "isSnooze": true
        ]

        // Critical sound/level only when the entitlement-backed setting is on
        checkCriticalAlertsEnabled { criticalEnabled in
            content.interruptionLevel = criticalEnabled ? .critical : .timeSensitive
            content.sound = criticalEnabled ? .defaultCritical : .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
            let id = "snooze-\(alarmId)-\(Int(Date().timeIntervalSince1970))"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    ZeezLogger.error(ZeezLogger.alarm, "Failed to schedule basic snooze", error: error)
                } else {
                    ZeezLogger.info(ZeezLogger.alarm, "💤 Basic snooze scheduled for \(minutes) minutes")
                }
            }
        }
    }
    
    /// Check if user has critical alerts enabled
    static func checkCriticalAlertsEnabled(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let enabled = (settings.criticalAlertSetting == .enabled)
            completion(enabled)
        }
    }
    
    /// Get the appropriate interruption level based on device capabilities
    static func getInterruptionLevel(completion: @escaping (UNNotificationInterruptionLevel) -> Void) {
        checkCriticalAlertsEnabled { enabled in
            completion(enabled ? .critical : .timeSensitive)
        }
    }
    
    /// Get the appropriate sound based on device capabilities  
    static func getAlarmSound(completion: @escaping (UNNotificationSound) -> Void) {
        checkCriticalAlertsEnabled { enabled in
            completion(enabled ? .defaultCritical : .default)
        }
    }
    
    /// Get the appropriate snooze sound based on alarm configuration
    static func getSnoozeSound(alarmSound: String, criticalEnabled: Bool) -> UNNotificationSound {
        // Check for Zeez custom sounds first
        switch alarmSound {
        case "Alarm_Classic.caf":
            return UNNotificationSound(named: UNNotificationSoundName("Alarm_Classic.caf"))
        case "Alarm_Honk.caf":
            return UNNotificationSound(named: UNNotificationSoundName("Alarm_Honk.caf"))
        case "Alarm_Horn.caf":
            return UNNotificationSound(named: UNNotificationSoundName("Alarm_Horn.caf"))
        case "default":
            return criticalEnabled ? .defaultCritical : .default
        default:
            // Try as custom sound file
            if !alarmSound.isEmpty {
                return UNNotificationSound(named: UNNotificationSoundName(alarmSound))
            } else {
                return criticalEnabled ? .defaultCritical : .default
            }
        }
    }
    
    /// Cancel pending follow-up notifications for a specific alarm
    private static func cancelPendingFollowUps(for alarmId: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let followUpIds = requests.compactMap { request -> String? in
                // Match follow-up notifications for this alarm
                if request.identifier.contains("alarm-\(alarmId)-fu-") {
                    return request.identifier
                }
                return nil
            }
            
            if !followUpIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: followUpIds)
                ZeezLogger.info(ZeezLogger.alarm, "🙅 Snooze canceled \(followUpIds.count) pending follow-ups for alarm \(alarmId)")
            }
        }
    }
}