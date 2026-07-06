import UserNotifications

/// The slice of UNUserNotificationCenter the alarm scheduler uses.
///
/// Production injects the real center; tests inject an in-memory fake so
/// scheduling behavior (mains, follow-up chains, removals) can be asserted
/// without notification permission or a live center (roadmap 1.1/2.4).
protocol AlarmNotificationScheduling {
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?)
    func getPendingNotificationRequests(completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void)
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func getNotificationSettings(completionHandler: @escaping @Sendable (UNNotificationSettings) -> Void)
    /// Whether the entitlement-backed critical-alerts setting is enabled.
    /// A separate requirement (not derived at call sites from
    /// `getNotificationSettings`) because `UNNotificationSettings` cannot be
    /// constructed in tests — fakes answer this directly.
    func criticalAlertsEnabled(completionHandler: @escaping @Sendable (Bool) -> Void)
}

extension AlarmNotificationScheduling {
    func criticalAlertsEnabled(completionHandler: @escaping @Sendable (Bool) -> Void) {
        getNotificationSettings { settings in
            completionHandler(settings.criticalAlertSetting == .enabled)
        }
    }
}

extension UNUserNotificationCenter: AlarmNotificationScheduling {}
