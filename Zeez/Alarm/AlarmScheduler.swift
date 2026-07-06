import Foundation
import CoreData
import UserNotifications
import UIKit
import os.log

/// Manages scheduling and triggering of alarms
class AlarmScheduler: NSObject {
    static let shared = AlarmScheduler()

    private let notificationCenter: AlarmNotificationScheduling
    private let wakeManager = WakeUpProgressionManager.shared

    // Synchronization queue to prevent race conditions
    private let schedulingQueue = DispatchQueue(label: "com.zeez.alarmscheduler", qos: .userInitiated)
    private var isSchedulingInProgress = false

    /// Tests inject an in-memory fake center; production uses the real one.
    init(notificationCenter: AlarmNotificationScheduling = UNUserNotificationCenter.current()) {
        self.notificationCenter = notificationCenter
        super.init()
        // Note: Notification handling is now done by AlarmNotificationHandler
        // The delegate is set in ApplicationDelegate
    }

    /// Schedule all enabled alarms (use sparingly - prefer scheduleSpecificAlarm)
    ///
    /// Core Data is only touched inside `context.perform`; everything after the
    /// snapshot is Core-Data-free and ordered by chaining inside the
    /// notification-center callbacks (no semaphores — see item 1.6).
    func scheduleAllAlarms(context: NSManagedObjectContext) {
        context.perform { [weak self] in
            let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
            request.predicate = NSPredicate(format: "enabled == YES")

            guard let alarms = try? context.fetch(request) else {
                ZeezLogger.error(ZeezLogger.alarm, "Failed to fetch alarms for scheduling")
                return
            }

            let snapshots = alarms.compactMap(AlarmSnapshot.init)
            self?.scheduleAllSnapshots(snapshots)
        }
    }

    private func scheduleAllSnapshots(_ snapshots: [AlarmSnapshot]) {
        schedulingQueue.async { [weak self] in
            guard let self = self else { return }

            // Prevent multiple simultaneous scheduling operations
            guard !self.isSchedulingInProgress else {
                ZeezLogger.debug(ZeezLogger.alarm, "Scheduling already in progress, skipping duplicate request")
                return
            }
            self.isSchedulingInProgress = true

            ZeezLogger.info(ZeezLogger.alarm, "⚠️ Scheduling ALL \(snapshots.count) enabled alarms (this should be rare)")

            // Remove only alarm-owned notifications ("alarm-" mains/follow-ups) so
            // non-alarm requests (Learn reminders etc.) survive a full reschedule.
            // In-flight snoozes ("snooze-<uuid>-...") are deliberately kept unless
            // their owning alarm is no longer enabled (disabled or deleted) — a
            // reschedule on app launch must not silently cancel a running snooze.
            let enabledAlarmIDs = Set(snapshots.map(\.idString))

            self.notificationCenter.getPendingNotificationRequests { requests in
                let idsToRemove = requests.map(\.identifier).filter { id in
                    if id.hasPrefix("alarm-") { return true }
                    if id.hasPrefix("snooze-") {
                        return !enabledAlarmIDs.contains { id.hasPrefix("snooze-\($0)-") }
                    }
                    return false
                }
                if !idsToRemove.isEmpty {
                    self.notificationCenter.removePendingNotificationRequests(withIdentifiers: idsToRemove)
                }

                // Adds are serialized with the removal by the notification center,
                // so scheduling here cannot race the identifier removal above.
                for snapshot in snapshots {
                    self.scheduleSnapshot(snapshot)
                }

                ZeezLogger.info(ZeezLogger.alarm, "Completed scheduling all alarms")
                self.schedulingQueue.async { self.isSchedulingInProgress = false }

                // Budget audit (1.4) — deferred so the async adds above have
                // landed; logging only, the gate lives in scheduleFollowUpChain.
                self.schedulingQueue.asyncAfter(deadline: .now() + 2) {
                    self.logNotificationBudget()
                }
            }
        }
    }

    /// Schedule only a specific alarm (efficient for single alarm changes)
    func scheduleSpecificAlarm(_ alarm: AlarmConfiguration) {
        guard let context = alarm.managedObjectContext else { return }
        context.perform { [weak self] in
            guard let snapshot = AlarmSnapshot(alarm) else { return }
            self?.scheduleSpecificSnapshot(snapshot)
        }
    }

    private func scheduleSpecificSnapshot(_ snapshot: AlarmSnapshot) {
        schedulingQueue.async { [weak self] in
            guard let self = self else { return }

            // Alarm names are user content — log the id publicly, the name in debug only.
            ZeezLogger.info(ZeezLogger.alarm, "🎯 Rescheduling single alarm \(snapshot.idString)")
            ZeezLogger.debug(ZeezLogger.alarm, "   Alarm name: \(snapshot.name ?? "Unknown")")

            let alarmID = snapshot.idString
            self.notificationCenter.getPendingNotificationRequests { requests in
                // Identifiers are "alarm-<uuid>-main/fu-...", never bare "<uuid>...".
                // The alarm's snooze is kept while it remains enabled; a disabled
                // alarm must take its in-flight snooze with it.
                let identifiers = requests.map(\.identifier).filter { id in
                    if id.hasPrefix("alarm-\(alarmID)-") { return true }
                    if !snapshot.enabled, id.hasPrefix("snooze-\(alarmID)-") { return true }
                    return false
                }

                if !identifiers.isEmpty {
                    self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
                    ZeezLogger.debug(ZeezLogger.alarm, "   Removed \(identifiers.count) old notifications for this alarm")
                }

                // Schedule the updated alarm (serialized after the removal above)
                self.scheduleSnapshot(snapshot)
            }
        }
    }

    /// Schedule a single alarm (public interface - uses synchronization)
    func scheduleAlarm(_ alarm: AlarmConfiguration) {
        guard let context = alarm.managedObjectContext else { return }
        context.perform { [weak self] in
            guard let snapshot = AlarmSnapshot(alarm) else { return }
            self?.schedulingQueue.async {
                self?.scheduleSnapshot(snapshot)
            }
        }
    }

    /// Schedules the notifications for one alarm snapshot. Core-Data-free.
    private func scheduleSnapshot(_ snapshot: AlarmSnapshot) {
        guard snapshot.enabled,
              let time = snapshot.time,
              !snapshot.selectedDays.isEmpty else {
            ZeezLogger.error(ZeezLogger.alarm, "Cannot schedule alarm: missing required data")
            return
        }

        // Mains are scheduled before the follow-up chain so that if the
        // 64-request budget is tight, follow-ups are what get dropped (1.4).
        for dayOfWeek in snapshot.selectedDays {
            // If smart wake is enabled, schedule earlier for analysis
            let scheduledTime = snapshot.smartWakeEnabled ?
                time.addingTimeInterval(-Double(snapshot.smartWakeWindow) * 60) : time

            createNotificationForDay(
                for: snapshot,
                at: scheduledTime,
                dayOfWeek: dayOfWeek,
                isSmartWake: snapshot.smartWakeEnabled
            )

            // Also schedule the backup alarm if smart wake is enabled
            if snapshot.smartWakeEnabled {
                createNotificationForDay(
                    for: snapshot,
                    at: time,
                    dayOfWeek: dayOfWeek,
                    isSmartWake: false
                )
            }
        }

        scheduleFollowUpChain(for: snapshot)
    }

    // MARK: - Pre-scheduled follow-up chain (roadmap 1.1)

    /// Arms the "still ringing" follow-up chain for the alarm's NEXT firing
    /// only. Before this existed, follow-ups were armed in `willPresent` —
    /// i.e. only when the app was foregrounded at fire time — so Heavy
    /// Sleeper mode did nothing in the exact scenario it exists for (phone
    /// locked, app suspended/killed).
    ///
    /// Budget notes (1.4): next-firing-day only (not all 7 weekdays), and a
    /// shorter chain (6/8) than the dynamic one. The chain is re-armed on
    /// every reschedule — app launch, alarm edits, significantTimeChange —
    /// and from the Stop action handler after it cancels the consumed chain.
    /// If the app stays closed past the next firing, later firings ring the
    /// main alarm but have no chain until any of those re-arm points runs.
    ///
    /// If the app IS foregrounded at fire time, `handleNotificationArrived`
    /// replaces this chain with a dynamic one anchored at the actual fire
    /// moment, so the two mechanisms never double-fire.
    func scheduleFollowUpChain(for snapshot: AlarmSnapshot) {
        guard snapshot.enabled,
              let nextFire = snapshot.nextFireDate() else { return }

        let cadence = AlarmNotificationUtils.getCadence(isHeavySleeper: snapshot.heavySleeperMode)
        let count = AlarmNotificationUtils.getPreScheduledFollowUps(isHeavySleeper: snapshot.heavySleeperMode)
        let alarmID = snapshot.idString
        let selectedSound = snapshot.alarmSound ?? "default"
        let vibrationOnly = snapshot.vibrationOnly
        let chainStamp = Int(nextFire.timeIntervalSince1970)

        // Budget gate (1.4): mains are scheduled before chains, and a chain
        // that would push past the 64-request cap is skipped entirely — the
        // system must never be left to silently drop a MAIN fire instead.
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            let budget = NotificationBudget(requests: requests)
            guard budget.canFit(count) else {
                ZeezLogger.error(ZeezLogger.alarm, "⚠️ Notification budget tight — skipping follow-up chain for alarm \(alarmID) (\(budget.summary))")
                return
            }
            self.armFollowUpChain(alarmID: alarmID, nextFire: nextFire, cadence: cadence,
                                  count: count, selectedSound: selectedSound,
                                  vibrationOnly: vibrationOnly, chainStamp: chainStamp)
        }
    }

    private func armFollowUpChain(alarmID: String, nextFire: Date, cadence: TimeInterval,
                                  count: Int, selectedSound: String,
                                  vibrationOnly: Bool, chainStamp: Int) {
        notificationCenter.criticalAlertsEnabled { [weak self] criticalEnabled in
            guard let self = self else { return }
            let calendar = Calendar.current

            for n in 1...count {
                let fireDate = nextFire.addingTimeInterval(cadence * Double(n))
                let content = UNMutableNotificationContent()
                content.title = ""
                content.body = ""
                content.categoryIdentifier = AlarmNotificationRegistrar.categoryId
                content.userInfo = ["alarmID": alarmID, "type": "fu"]
                content.interruptionLevel = criticalEnabled ? .critical : .timeSensitive
                if vibrationOnly {
                    content.sound = nil
                } else {
                    content.sound = self.getAlarmSoundForNotification(selectedSound, criticalEnabled: criticalEnabled)
                }

                // One-shot absolute-time trigger for the next firing only
                let components = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second], from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                // "alarm-<uuid>-fu-" prefix keeps these targetable by cancelFollowUps
                let id = "alarm-\(alarmID)-fu-pre-\(n)-\(chainStamp)"
                self.notificationCenter.add(
                    UNNotificationRequest(identifier: id, content: content, trigger: trigger),
                    withCompletionHandler: nil
                )
            }

            ZeezLogger.info(ZeezLogger.alarm, "📅 Pre-armed \(count) follow-ups for alarm \(alarmID) at next fire \(nextFire)")
        }
    }

    /// Re-arms the chain for an alarm's next firing from a notification
    /// action handler (the Stop action consumes the current chain).
    func rearmFollowUpChain(alarmId: String) {
        AlarmSnapshot.fetch(idString: alarmId) { [weak self] snapshot in
            guard let snapshot = snapshot else { return }
            self?.schedulingQueue.async {
                self?.scheduleFollowUpChain(for: snapshot)
            }
        }
    }
    
    /// Cancel all scheduled alarms (mains, follow-ups, and snoozes).
    /// Removes only alarm-owned identifiers so other notifications
    /// (Learn reminders etc.) are untouched.
    func cancelAllAlarms() {
        schedulingQueue.async { [weak self] in
            guard let self = self else { return }
            self.notificationCenter.getPendingNotificationRequests { requests in
                let ids = requests.map(\.identifier)
                    .filter { $0.hasPrefix("alarm-") || $0.hasPrefix("snooze-") }
                if !ids.isEmpty {
                    self.notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
                }
                ZeezLogger.info(ZeezLogger.alarm, "Cancelled \(ids.count) scheduled alarm notifications")
            }
        }
    }
    
    /// Logs the per-category pending-notification totals against the 64 cap.
    func logNotificationBudget() {
        notificationCenter.getPendingNotificationRequests { requests in
            let budget = NotificationBudget(requests: requests)
            if budget.isNearCap {
                ZeezLogger.error(ZeezLogger.alarm, "⚠️ Notification budget near cap: \(budget.summary)")
            } else {
                ZeezLogger.info(ZeezLogger.alarm, "Notification budget: \(budget.summary)")
            }
        }
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
        content.categoryIdentifier = AlarmNotificationRegistrar.categoryId

        // Critical sound/level only when the entitlement-backed setting is on
        notificationCenter.criticalAlertsEnabled { [weak self] criticalEnabled in
            content.sound = criticalEnabled ? .defaultCritical : .default
            content.interruptionLevel = criticalEnabled ? .critical : .timeSensitive

            // Schedule for 10 seconds from now
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)

            self?.notificationCenter.add(request) { error in
                if let error = error {
                    ZeezLogger.error(ZeezLogger.alarm, "Failed to schedule test notification", error: error)
                } else {
                    ZeezLogger.info(ZeezLogger.alarm, "✅ Test notification scheduled for 10 seconds from now")
                }
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
    
    private func createNotificationForDay(
        for alarm: AlarmSnapshot,
        at time: Date,
        dayOfWeek: Int,
        isSmartWake: Bool
    ) {
        let alarmID = alarm.idString

        let content = UNMutableNotificationContent()
        let alarmName = alarm.name ?? ""
        content.title = alarmName.isEmpty ? "Alarm" : alarmName
        content.body = isSmartWake ? "Gentle wake-up — your alarm is coming soon" : "Time to Wake Up"
        
        // Add action buttons to the notification using new system
        content.categoryIdentifier = AlarmNotificationRegistrar.categoryId
        content.userInfo = [
            "alarmID": alarmID,
            "isSmartWake": isSmartWake,
            "dayOfWeek": dayOfWeek,
            "type": "main"  // Important: mark as main alarm for follow-up logic
        ]
        
        // Create calendar components for scheduling with specific day of week
        var components = Calendar.current.dateComponents([.hour, .minute], from: time)
        components.weekday = dayOfWeek // 1 = Sunday, 2 = Monday, etc.
        
        // Create trigger
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        // Create unique identifier with stable main format for easy targeting
        let timestamp = Int(time.timeIntervalSince1970)
        let identifier = "alarm-\(alarmID)-main-\(timestamp)-day\(dayOfWeek)-\(isSmartWake ? "smart" : "standard")"
        
        // Prepare sound selection outside the closure
        let selectedSound = alarm.alarmSound ?? "default"
        
        // Check critical alert capability and set appropriate interruption level and sound
        notificationCenter.criticalAlertsEnabled { [weak self] criticalEnabled in
            if isSmartWake {
                // The gentle pre-alarm is deliberately quieter than the real
                // alarm: default sound, never critical. The backup alert at the
                // actual alarm time carries the full loudness.
                content.interruptionLevel = .timeSensitive
                content.sound = alarm.vibrationOnly ? nil : .default
            } else {
                content.interruptionLevel = criticalEnabled ? .critical : .timeSensitive

                // Use user's selected alarm sound
                if alarm.vibrationOnly {
                    content.sound = nil
                } else {
                    content.sound = self?.getAlarmSoundForNotification(selectedSound, criticalEnabled: criticalEnabled) ?? .default
                }
            }
            
            // Log the resolved sound for debugging
            let soundDesc = content.sound?.description ?? "none"
            ZeezLogger.info(ZeezLogger.alarm, "📅 Scheduled sound: \(selectedSound) -> \(soundDesc) / critical: \(criticalEnabled)")
            
            // Create request
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            // Schedule notification
            self?.notificationCenter.add(request) { error in
                if let error = error {
                    ZeezLogger.error(ZeezLogger.alarm, "Error scheduling notification for \(identifier)", error: error)
                } else {
                    // Only log in debug builds to reduce console spam
                    #if DEBUG
                    ZeezLogger.debug(ZeezLogger.alarm, "✅ Scheduled \(identifier) for \(alarmName) at \(components.hour ?? 0):\(String(format: "%02d", components.minute ?? 0))")
                    #endif
                }
            }
        }
    }
    
    /// Get the appropriate alarm sound for notifications, respecting critical alert capability
    private func getAlarmSoundForNotification(_ soundName: String, criticalEnabled: Bool) -> UNNotificationSound {
        // Check for Zeez custom sounds first
        switch soundName {
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
            if !soundName.isEmpty {
                return UNNotificationSound(named: UNNotificationSoundName(soundName))
            } else {
                return criticalEnabled ? .defaultCritical : .default
            }
        }
    }
    
    /// Get the appropriate alarm sound for the given sound name (legacy method for compatibility)
    func getAlarmSound(for soundName: String) -> UNNotificationSound {
        return getAlarmSoundForNotification(soundName, criticalEnabled: true) // Default to critical for backward compatibility
    }
}