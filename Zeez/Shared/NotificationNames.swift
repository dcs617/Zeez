import Foundation

/// Cross-component NotificationCenter names (2.5-E — previously stringly-typed at each site).
extension Notification.Name {
    /// Posted by the alarm stack when the full-screen ActiveAlarmView should present.
    /// Object: the `AlarmConfiguration` that fired.
    static let showActiveAlarm = Notification.Name("ShowActiveAlarm")

    /// Posted when the user tries to enable an alarm without notification permission.
    static let alarmPermissionDenied = Notification.Name("AlarmPermissionDenied")

    /// Posted by RootView when a coordinator-driven sheet dismisses, so observers
    /// (e.g. Settings) can refresh their data status.
    static let modalDismissed = Notification.Name("ModalDismissed")
}
