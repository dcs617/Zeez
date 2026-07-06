import UserNotifications

/// Accounting for iOS's 64-pending-notification cap (roadmap 1.4).
///
/// Beyond 64 pending requests the system silently drops notifications — an
/// alarm that never fires, with no error. Mains are always scheduled before
/// follow-up chains, and `AlarmScheduler` skips arming a chain that would not
/// fit (`canFit`), so main fires are never the ones displaced.
struct NotificationBudget {
    /// iOS's hard cap on pending notification requests per app.
    static let systemCap = 64
    /// Headroom the chain scheduler keeps free for snoozes and Learn reminders.
    static let chainSafetyMargin = 4
    /// Below this much remaining room, AlarmSettingsView shows a warning.
    static let warningHeadroom = 10

    let mains: Int
    let followUps: Int
    let snoozes: Int
    let other: Int

    init(requests: [UNNotificationRequest]) {
        var mains = 0, followUps = 0, snoozes = 0, other = 0
        for identifier in requests.map(\.identifier) {
            if identifier.hasPrefix("snooze-") {
                snoozes += 1
            } else if identifier.hasPrefix("alarm-") && identifier.contains("-fu-") {
                followUps += 1
            } else if identifier.hasPrefix("alarm-") {
                mains += 1
            } else {
                other += 1
            }
        }
        self.mains = mains
        self.followUps = followUps
        self.snoozes = snoozes
        self.other = other
    }

    var total: Int { mains + followUps + snoozes + other }

    var remaining: Int { max(0, Self.systemCap - total) }

    var isNearCap: Bool { remaining <= Self.warningHeadroom }

    /// Whether `count` more requests fit while keeping `margin` slots free.
    func canFit(_ count: Int, keepingFree margin: Int = NotificationBudget.chainSafetyMargin) -> Bool {
        total + count + margin <= Self.systemCap
    }

    var summary: String {
        "mains: \(mains), follow-ups: \(followUps), snoozes: \(snoozes), other: \(other) — total \(total)/\(Self.systemCap)"
    }
}
