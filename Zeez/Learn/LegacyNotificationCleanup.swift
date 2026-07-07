import Foundation
import UserNotifications
import os.log

/// One-time removal of pending notification requests scheduled by builds that
/// predate the prefix-based identifier schemes from roadmap items 0.5/0.6.
///
/// Those builds scheduled Learn notifications with un-prefixed identifiers
/// (`challenge_*`, `challenge_completion_*`, `learning_*`, `streak_reminder_*`,
/// `snoozed_*`). The prefix-filtered removal paths introduced in 0.5/0.6 only
/// match the current `learn-`/`alarm-`/`snooze-` schemes, so legacy requests on
/// an upgraded install could never be cancelled again (2.7). Every current
/// identifier carries one of the new prefixes, so a plain prefix match here can
/// only ever hit legacy requests.
enum LegacyNotificationCleanup {
    static let completedDefaultsKey = "legacyLearnNotificationCleanupDone"

    /// `challenge_` also covers `challenge_completion_`.
    static let legacyPrefixes = ["challenge_", "learning_", "streak_reminder_", "snoozed_"]

    /// Runs at most once per install (UserDefaults flag). Injectable center and
    /// defaults for tests; production uses the real ones from `ZeezApp.setupApp()`.
    static func runOnce(center: AlarmNotificationScheduling = UNUserNotificationCenter.current(),
                        defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: completedDefaultsKey) else { return }

        // Flag is set before the async enumeration completes (UserDefaults is not
        // Sendable, so it can't cross into the callback). If the process dies in
        // the tiny window before removal lands, the stale requests simply persist —
        // the same state as never running, and no external installs exist yet.
        defaults.set(true, forKey: completedDefaultsKey)

        center.getPendingNotificationRequests { requests in
            let legacyIDs = requests.map(\.identifier).filter { id in
                legacyPrefixes.contains { id.hasPrefix($0) }
            }
            if !legacyIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: legacyIDs)
                ZeezLogger.info(ZeezLogger.learning, "Removed \(legacyIDs.count) legacy Learn notification requests")
            }
        }
    }
}
