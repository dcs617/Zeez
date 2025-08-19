import Foundation
import CoreData
import UserNotifications
import UIKit
import os.log

/// Manages scheduling and triggering of alarms
class AlarmScheduler: NSObject {
    static let shared = AlarmScheduler()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let wakeManager = WakeUpProgressionManager.shared
    
    override init() {
        super.init()
        setupNotificationHandling()
    }

    /// Schedule all enabled alarms (use sparingly - prefer scheduleSpecificAlarm)
    func scheduleAllAlarms(context: NSManagedObjectContext) {
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == YES")
        
        guard let alarms = try? context.fetch(request) else { 
            ZeezLogger.error(ZeezLogger.alarm, "Failed to fetch alarms for scheduling")
            return 
        }
        
        ZeezLogger.info(ZeezLogger.alarm, "⚠️ Scheduling ALL \(alarms.count) enabled alarms (this should be rare)")
        
        // Remove all pending alarm notifications first
        notificationCenter.removeAllPendingNotificationRequests()
        
        // Schedule each alarm
        for alarm in alarms {
            scheduleAlarm(alarm)
        }
        
        ZeezLogger.info(ZeezLogger.alarm, "Completed scheduling all alarms")
    }
    
    /// Schedule only a specific alarm (efficient for single alarm changes)
    func scheduleSpecificAlarm(_ alarm: AlarmConfiguration) {
        guard let alarmID = alarm.id?.uuidString else { return }
        
        ZeezLogger.info(ZeezLogger.alarm, "🎯 Rescheduling single alarm: \(alarm.name ?? "Unknown")")
        
        // Remove only notifications for this specific alarm
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let alarmRequests = requests.filter { $0.identifier.hasPrefix(alarmID) }
            let identifiers = alarmRequests.map { $0.identifier }
            
            if !identifiers.isEmpty {
                self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
                ZeezLogger.debug(ZeezLogger.alarm, "   Removed \(identifiers.count) old notifications for this alarm")
            }
            
            // Schedule the updated alarm
            self?.scheduleAlarm(alarm)
        }
    }
    
    /// Schedule a single alarm
    func scheduleAlarm(_ alarm: AlarmConfiguration) {
        guard alarm.enabled,
              let time = alarm.time,
              let daysData = alarm.daysOfWeek,
              let selectedDays = try? JSONDecoder().decode(Set<Int>.self, from: daysData),
              !selectedDays.isEmpty else { 
            ZeezLogger.error(ZeezLogger.alarm, "Cannot schedule alarm: missing required data")
            return 
        }
        
        // Schedule for each selected day of the week
        for dayOfWeek in selectedDays {
            // If smart wake is enabled, schedule earlier for analysis
            let scheduledTime = alarm.smartWakeEnabled ?
                time.addingTimeInterval(-Double(alarm.smartWakeWindow) * 60) : time
            
            createNotificationForDay(
                for: alarm,
                at: scheduledTime,
                dayOfWeek: dayOfWeek,
                isSmartWake: alarm.smartWakeEnabled
            )
            
            // Also schedule the backup alarm if smart wake is enabled
            if alarm.smartWakeEnabled {
                createNotificationForDay(
                    for: alarm,
                    at: time,
                    dayOfWeek: dayOfWeek,
                    isSmartWake: false
                )
            }
        }
    }
    
    /// Cancel all scheduled alarms
    func cancelAllAlarms() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    /// Debug function to check scheduled notifications
    func debugScheduledAlarms() {
        notificationCenter.getPendingNotificationRequests { requests in
            ZeezLogger.info(ZeezLogger.alarm, "=== DEBUG: Scheduled Notifications ===")
            ZeezLogger.info(ZeezLogger.alarm, "Total pending notifications: \(requests.count)")
            
            for request in requests {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    let components = trigger.dateComponents
                    let hour = components.hour ?? 0
                    let minute = components.minute ?? 0
                    let weekday = components.weekday ?? 0
                    
                    let weekdayName = weekday > 0 && weekday <= Calendar.current.weekdaySymbols.count 
                        ? Calendar.current.weekdaySymbols[weekday - 1] 
                        : "Unknown"
                    
                    ZeezLogger.info(ZeezLogger.alarm, "📅 \(request.identifier): \(weekdayName) at \(hour):\(String(format: "%02d", minute))")
                    ZeezLogger.info(ZeezLogger.alarm, "   Title: \(request.content.title)")
                    ZeezLogger.info(ZeezLogger.alarm, "   Body: \(request.content.body)")
                    ZeezLogger.info(ZeezLogger.alarm, "   Sound: \(request.content.sound?.description ?? "None")")
                }
            }
            ZeezLogger.info(ZeezLogger.alarm, "=== End Debug ===")
        }
    }
    
    /// Get current notification authorization status
    func checkNotificationPermissions(completion: @escaping (UNAuthorizationStatus) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }
    
    /// Manual test function to verify notification system
    func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Zeez Alarm Test"
        content.body = "This is a test notification to verify alarm system works"
        content.sound = .defaultCritical
        content.interruptionLevel = .critical
        content.categoryIdentifier = "ALARM_CATEGORY"
        
        // Schedule for 10 seconds from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                ZeezLogger.error(ZeezLogger.alarm, "Failed to schedule test notification", error: error)
            } else {
                ZeezLogger.info(ZeezLogger.alarm, "✅ Test notification scheduled for 10 seconds from now")
            }
        }
    }
    
    /// Test if current pending notifications are valid
    func validatePendingNotifications() {
        notificationCenter.getPendingNotificationRequests { requests in
            ZeezLogger.info(ZeezLogger.alarm, "📋 Validating \(requests.count) pending notifications")
            
            for request in requests {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    let components = trigger.dateComponents
                    
                    // Check if this notification would fire in the next 24 hours
                    let nextTrigger = Calendar.current.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)
                    
                    if let nextDate = nextTrigger {
                        let timeUntil = nextDate.timeIntervalSinceNow
                        if timeUntil <= 24 * 60 * 60 { // Within 24 hours
                            ZeezLogger.info(ZeezLogger.alarm, "   ⏰ \(request.identifier) will fire in \(Int(timeUntil/60)) minutes")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationHandling() {
        notificationCenter.delegate = self
        
        // Set up notification actions
        setupNotificationActions()
        
        // Request notification permissions including critical alerts for alarms
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
        notificationCenter.requestAuthorization(options: options) { granted, error in
            if let error = error {
                ZeezLogger.error(ZeezLogger.alarm, "Error requesting notification permission", error: error)
            } else if granted {
                ZeezLogger.info(ZeezLogger.alarm, "Notification permissions granted (including critical alerts)")
            } else {
                ZeezLogger.error(ZeezLogger.alarm, "Notification permissions denied - alarms will not work")
            }
        }
    }
    
    private func setupNotificationActions() {
        // Create snooze action
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_ACTION",
            title: "Snooze",
            options: []
        )
        
        // Create stop action
        let stopAction = UNNotificationAction(
            identifier: "STOP_ACTION", 
            title: "Stop",
            options: [.destructive]
        )
        
        // Create alarm category
        let alarmCategory = UNNotificationCategory(
            identifier: "ALARM_CATEGORY",
            actions: [snoozeAction, stopAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Register the category
        notificationCenter.setNotificationCategories([alarmCategory])
    }
    
    private func createNotificationForDay(
        for alarm: AlarmConfiguration,
        at time: Date,
        dayOfWeek: Int,
        isSmartWake: Bool
    ) {
        guard let alarmID = alarm.id?.uuidString else { return }
        
        let content = UNMutableNotificationContent()
        let alarmName = alarm.name ?? ""
        content.title = alarmName.isEmpty ? "Alarm" : alarmName
        content.body = isSmartWake ? "Smart Wake Initializing" : "Time to Wake Up"
        
        // Make this a critical alert that bypasses Do Not Disturb
        content.interruptionLevel = .critical
        
        // Use proper alarm sound - always use default critical for reliability
        if alarm.vibrationOnly {
            content.sound = nil
        } else {
            // Always use default critical alert sound for maximum reliability
            content.sound = .defaultCritical
        }
        
        // Add action buttons to the notification
        content.categoryIdentifier = "ALARM_CATEGORY"
        content.userInfo = [
            "alarmID": alarmID,
            "isSmartWake": isSmartWake,
            "dayOfWeek": dayOfWeek
        ]
        
        // Create calendar components for scheduling with specific day of week
        var components = Calendar.current.dateComponents([.hour, .minute], from: time)
        components.weekday = dayOfWeek // 1 = Sunday, 2 = Monday, etc.
        
        // Get weekday name for logging
        let weekdayName = dayOfWeek > 0 && dayOfWeek <= Calendar.current.weekdaySymbols.count 
            ? Calendar.current.weekdaySymbols[dayOfWeek - 1] 
            : "Day\(dayOfWeek)"
        
        // Create trigger
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        // Create unique identifier including day of week
        let identifier = "\(alarmID)-day\(dayOfWeek)-\(isSmartWake ? "smart" : "standard")"
        
        // Create request
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        notificationCenter.add(request) { error in
            if let error = error {
                ZeezLogger.error(ZeezLogger.alarm, "Error scheduling notification for day \(dayOfWeek)", error: error)
            } else {
                // Only log in debug builds to reduce console spam
                #if DEBUG
                ZeezLogger.debug(ZeezLogger.alarm, "✅ Scheduled \(identifier) for \(weekdayName) \(components.hour ?? 0):\(String(format: "%02d", components.minute ?? 0))")
                #endif
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AlarmScheduler: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        ZeezLogger.info(ZeezLogger.alarm, "🔔 Alarm notification will present: \(notification.request.identifier)")
        ZeezLogger.debug(ZeezLogger.alarm, "   App state: \(UIApplication.shared.applicationState.rawValue)")
        
        handleNotification(notification)
        
        // Show full-screen alarm if app is active
        if UIApplication.shared.applicationState == .active {
            ZeezLogger.info(ZeezLogger.alarm, "   App is active - showing full-screen alarm")
            showFullScreenAlarm(for: notification)
            completionHandler([.sound]) // Still play sound even when showing full-screen
        } else {
            ZeezLogger.info(ZeezLogger.alarm, "   App is backgrounded - showing banner")
            completionHandler([.banner, .sound]) // Show banner when app is backgrounded
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        ZeezLogger.info(ZeezLogger.alarm, "💆 Alarm notification response received: \(response.actionIdentifier)")
        
        // Handle action responses
        switch response.actionIdentifier {
        case "SNOOZE_ACTION":
            ZeezLogger.info(ZeezLogger.alarm, "   User chose to snooze")
            handleSnoozeAction(for: response.notification)
        case "STOP_ACTION":
            ZeezLogger.info(ZeezLogger.alarm, "   User chose to stop")
            handleStopAction(for: response.notification)
        case UNNotificationDefaultActionIdentifier:
            ZeezLogger.info(ZeezLogger.alarm, "   User tapped notification")
            // User tapped the notification itself
            handleNotification(response.notification)
            showFullScreenAlarm(for: response.notification)
        default:
            ZeezLogger.info(ZeezLogger.alarm, "   Unknown action: \(response.actionIdentifier)")
            handleNotification(response.notification)
        }
        
        completionHandler()
    }
    
    private func handleNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        guard let alarmID = userInfo["alarmID"] as? String,
              let isSmartWake = userInfo["isSmartWake"] as? Bool else { return }
        
        // Find the alarm in CoreData
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", alarmID)
        
        guard let alarm = try? context.fetch(request).first else { return }
        
        // Handle smart wake differently from standard alarm
        if isSmartWake {
            handleSmartWake(alarm)
        } else {
            handleStandardWake(alarm)
        }
    }
    
    private func handleSmartWake(_ alarm: AlarmConfiguration) {
        guard let context = alarm.managedObjectContext else { return }
        
        // Find active sleep session
        let sessionRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        sessionRequest.predicate = NSPredicate(format: "isActive == YES")
        
        guard let activeSession = try? context.fetch(sessionRequest).first else {
            // No active session, fall back to standard wake
            handleStandardWake(alarm)
            return
        }
        
        // Start smart wake sequence
        wakeManager.startWakeSequence(
            for: alarm,
            sleepSession: activeSession
        ) { response in
            switch response {
            case .acknowledged:
                // User woke up, end sleep session
                activeSession.isActive = false
                activeSession.endTime = Date()
                try? context.save()
                
            case .snoozed:
                // Handled by WakeUpProgressionManager
                break
                
            case .backupTriggered:
                // Fall back to standard wake
                self.handleStandardWake(alarm)
            }
        }
    }
    
    private func handleStandardWake(_ alarm: AlarmConfiguration) {
        // Trigger standard alarm notification with sound
        let content = UNMutableNotificationContent()
        content.title = "Wake Up"
        content.body = "Alarm"
        
        // Use proper alarm sound - always use default critical for reliability
        if alarm.vibrationOnly {
            content.sound = nil
        } else {
            // Always use default critical alert sound for maximum reliability
            content.sound = .defaultCritical
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    /// Handle snooze action from notification
    private func handleSnoozeAction(for notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        guard let alarmID = userInfo["alarmID"] as? String else { return }
        
        // Find the alarm
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", alarmID)
        
        guard let alarm = try? context.fetch(request).first else { return }
        
        // Schedule snooze notification (9 minutes from now)
        let snoozeTime = Date().addingTimeInterval(9 * 60)
        scheduleSnoozeNotification(for: alarm, at: snoozeTime)
        
        ZeezLogger.info(ZeezLogger.alarm, "Alarm snoozed for 9 minutes via notification action")
    }
    
    /// Handle stop action from notification  
    private func handleStopAction(for notification: UNNotification) {
        ZeezLogger.info(ZeezLogger.alarm, "Alarm stopped via notification action")
        // No additional action needed - alarm is already stopped
    }
    
    /// Schedule a snooze notification
    private func scheduleSnoozeNotification(for alarm: AlarmConfiguration, at time: Date) {
        let content = UNMutableNotificationContent()
        content.title = alarm.name ?? "Alarm"
        content.body = "Snooze time's up!"
        content.interruptionLevel = .critical
        content.categoryIdentifier = "ALARM_CATEGORY"
        
        if !alarm.vibrationOnly {
            let soundName = alarm.alarmSound ?? "default"
            content.sound = getAlarmSound(for: soundName)
        }
        
        let timeInterval = time.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "snooze-\(alarm.id?.uuidString ?? UUID().uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                ZeezLogger.error(ZeezLogger.alarm, "Failed to schedule snooze", error: error)
            } else {
                ZeezLogger.info(ZeezLogger.alarm, "Snooze notification scheduled")
            }
        }
    }
    
    /// Show full-screen alarm interface
    private func showFullScreenAlarm(for notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        guard let alarmID = userInfo["alarmID"] as? String else { return }
        
        // Find the alarm in CoreData
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", alarmID)
        
        guard let alarm = try? context.fetch(request).first else { return }
        
        // Post notification to show full-screen alarm
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowActiveAlarm"),
                object: alarm
            )
        }
    }
    
    /// Get the appropriate alarm sound for the given sound name
    func getAlarmSound(for soundName: String) -> UNNotificationSound {
        switch soundName.lowercased() {
        // iOS built-in alarm sounds
        case "radar":
            return UNNotificationSound(named: UNNotificationSoundName("Radar.m4a"))
        case "apex":
            return UNNotificationSound(named: UNNotificationSoundName("Apex.m4a"))
        case "beacon":
            return UNNotificationSound(named: UNNotificationSoundName("Beacon.m4a"))
        case "bulletin":
            return UNNotificationSound(named: UNNotificationSoundName("Bulletin.m4a"))
        case "by_the_seaside":
            return UNNotificationSound(named: UNNotificationSoundName("By_The_Seaside.m4a"))
        case "chimes":
            return UNNotificationSound(named: UNNotificationSoundName("Chimes.m4a"))
        case "circuit":
            return UNNotificationSound(named: UNNotificationSoundName("Circuit.m4a"))
        case "cosmic":
            return UNNotificationSound(named: UNNotificationSoundName("Cosmic.m4a"))
        case "hillside":
            return UNNotificationSound(named: UNNotificationSoundName("Hillside.m4a"))
        case "night_owl":
            return UNNotificationSound(named: UNNotificationSoundName("Night_Owl.m4a"))
        case "opening":
            return UNNotificationSound(named: UNNotificationSoundName("Opening.m4a"))
        case "presto":
            return UNNotificationSound(named: UNNotificationSoundName("Presto.m4a"))
        case "sencha":
            return UNNotificationSound(named: UNNotificationSoundName("Sencha.m4a"))
        case "silk":
            return UNNotificationSound(named: UNNotificationSoundName("Silk.m4a"))
        case "slow_rise":
            return UNNotificationSound(named: UNNotificationSoundName("Slow_Rise.m4a"))
        case "summit":
            return UNNotificationSound(named: UNNotificationSoundName("Summit.m4a"))
        case "uplift":
            return UNNotificationSound(named: UNNotificationSoundName("Uplift.m4a"))
        default:
            // Default system alarm sound or custom sound
            if soundName != "default" {
                // Try custom sound first
                return UNNotificationSound(named: UNNotificationSoundName(soundName))
            } else {
                return .defaultCritical // Use critical alert sound for alarms
            }
        }
    }
}
