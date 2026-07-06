import UserNotifications
import os.log

enum AlarmNotificationRegistrar {
    static let categoryId = "ZEEZ_ALARM"
    static let stopId     = "ALARM_STOP"
    static let snoozeId   = "ALARM_SNOOZE"
    static let contId     = "ALARM_CONTINUE"

    static func registerCategories(_ center: UNUserNotificationCenter = .current()) {
        let snooze = UNNotificationAction(identifier: snoozeId, title: "Snooze", options: [])
        let cont   = UNNotificationAction(identifier: contId,   title: "Continue", options: [.foreground])
        let stop   = UNNotificationAction(identifier: stopId,   title: "Stop", options: [.destructive])

        let cat = UNNotificationCategory(
            identifier: categoryId,
            actions: [snooze, cont, stop],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([cat])
        
        ZeezLogger.info(ZeezLogger.alarm, "✅ Registered alarm notification categories")
    }

    static func requestAuthorization(_ center: UNUserNotificationCenter = .current()) {
        // Use the new permission manager for better UX
        AlarmPermissionManager.shared.requestPermissionsWithExplainer()
    }

    /// Call this once at app launch (see ApplicationDelegate).
    static func prepare(delegate: UNUserNotificationCenterDelegate, center: UNUserNotificationCenter = .current()) {
        center.delegate = delegate
        registerCategories(center)
        
        // Check if we should show permission explainer instead of immediately requesting
        AlarmPermissionManager.shared.checkIfShouldShowExplainer()
        
        ZeezLogger.info(ZeezLogger.alarm, "🚀 Alarm notification system prepared")
    }
}