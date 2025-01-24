import Foundation
import CoreData
import UserNotifications

/// Manages scheduling and triggering of alarms
class AlarmScheduler: NSObject {
    static let shared = AlarmScheduler()

    private let notificationCenter = UNUserNotificationCenter.current()
    private let wakeManager = WakeUpProgressionManager.shared
    
    override init() {
        super.init()
        setupNotificationHandling()
    }

    /// Schedule all enabled alarms
    func scheduleAllAlarms(context: NSManagedObjectContext) {
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == YES")
        
        guard let alarms = try? context.fetch(request) else { return }
        
        // Remove all pending notifications first
        notificationCenter.removeAllPendingNotificationRequests()
        
        // Schedule each alarm
        for alarm in alarms {
            scheduleAlarm(alarm)
        }
    }
    
    /// Schedule a single alarm
    func scheduleAlarm(_ alarm: AlarmConfiguration) {
        guard alarm.enabled,
              let time = alarm.time else { return }
        
        // If smart wake is enabled, schedule earlier for analysis
        let scheduledTime = alarm.smartWakeEnabled ?
            time.addingTimeInterval(-Double(alarm.smartWakeWindow) * 60) : time
        
        createNotification(
            for: alarm,
            at: scheduledTime,
            isSmartWake: alarm.smartWakeEnabled
        )
    }
    
    /// Cancel all scheduled alarms
    func cancelAllAlarms() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationHandling() {
        notificationCenter.delegate = self
        
        // Request notification permissions if needed
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
    }
    
    private func createNotification(
        for alarm: AlarmConfiguration,
        at time: Date,
        isSmartWake: Bool
    ) {
        guard let alarmID = alarm.id?.uuidString else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Alarm"
        content.body = isSmartWake ? "Smart Wake Initializing" : "Time to Wake Up"
        content.sound = alarm.vibrationOnly ? nil : .default
        content.userInfo = [
            "alarmID": alarmID,
            "isSmartWake": isSmartWake
        ]
        
        // Create calendar components for scheduling
        let components = Calendar.current.dateComponents(
            [.hour, .minute],
            from: time
        )
        
        // Create trigger
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "\(alarmID)-\(isSmartWake ? "smart" : "standard")",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
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
        handleNotification(notification)
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleNotification(response.notification)
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
        content.sound = alarm.vibrationOnly ? nil : .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
}
