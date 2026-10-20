import Foundation
import UserNotifications

/// What the notification center actually holds for the user's alarms, as opposed to what
/// the alarm list says should be there (second-audit C5).
///
/// An alarm that is enabled in Core Data but has no pending main notification will not ring,
/// and nothing else in the app would show it: the row still says "on". This is the one
/// place that compares the two.
struct AlarmHealth: Equatable {
    /// The plain values read from a pending `UNNotificationRequest`.
    struct PendingRequest: Equatable {
        let identifier: String
        let nextFireDate: Date?

        init(identifier: String, nextFireDate: Date?) {
            self.identifier = identifier
            self.nextFireDate = nextFireDate
        }

        init(_ request: UNNotificationRequest) {
            self.identifier = request.identifier
            self.nextFireDate = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                ?? (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
        }

        var isAlarmOwned: Bool { identifier.hasPrefix("alarm-") || identifier.hasPrefix("snooze-") }

        /// Mains and snoozes ring; follow-ups only repeat a ring already in progress.
        var isRing: Bool {
            identifier.hasPrefix("snooze-") || (identifier.hasPrefix("alarm-") && identifier.contains("-main-"))
        }
    }

    enum Status: Equatable {
        /// No enabled alarms, so there is nothing to check.
        case noEnabledAlarms
        /// Notification permission is missing; no alarm can ring.
        case notificationsOff
        /// This many enabled alarms have no pending main notification.
        case alarmsNotScheduled(Int)
        case healthy
    }

    /// Alarm-owned pending notifications: mains, follow-ups and snoozes.
    let scheduledCount: Int
    /// The earliest upcoming main or snooze.
    let nextRingDate: Date?
    /// Enabled alarms with no pending main notification.
    let unscheduledAlarmIDs: Set<String>
    let status: Status

    init(pending: [PendingRequest], enabledAlarmIDs: Set<String>,
         authorization: UNAuthorizationStatus, now: Date = Date()) {
        let owned = pending.filter(\.isAlarmOwned)
        scheduledCount = owned.count
        nextRingDate = owned
            .filter(\.isRing)
            .compactMap(\.nextFireDate)
            .filter { $0 > now }
            .min()
        unscheduledAlarmIDs = enabledAlarmIDs.filter { id in
            !pending.contains { $0.identifier.hasPrefix("alarm-\(id)-main-") }
        }

        if enabledAlarmIDs.isEmpty {
            status = .noEnabledAlarms
        } else if !Self.allowsAlerts(authorization) {
            status = .notificationsOff
        } else if !unscheduledAlarmIDs.isEmpty {
            status = .alarmsNotScheduled(unscheduledAlarmIDs.count)
        } else {
            status = .healthy
        }
    }

    static func allowsAlerts(_ authorization: UNAuthorizationStatus) -> Bool {
        switch authorization {
        case .authorized, .provisional, .ephemeral: return true
        case .denied, .notDetermined: return false
        @unknown default: return false
        }
    }

    /// Reads the pending requests from `center` and delivers the result on the main queue.
    static func load(enabledAlarmIDs: Set<String>, authorization: UNAuthorizationStatus,
                     center: AlarmNotificationScheduling = UNUserNotificationCenter.current(),
                     completion: @escaping (AlarmHealth) -> Void) {
        center.getPendingNotificationRequests { requests in
            let health = AlarmHealth(pending: requests.map(PendingRequest.init),
                                     enabledAlarmIDs: enabledAlarmIDs,
                                     authorization: authorization)
            DispatchQueue.main.async {
                completion(health)
            }
        }
    }
}
