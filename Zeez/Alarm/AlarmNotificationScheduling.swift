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
}

extension UNUserNotificationCenter: AlarmNotificationScheduling {}
