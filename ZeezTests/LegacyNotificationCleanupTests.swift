import Testing
import UserNotifications
@testable import Zeez

/// Tests for the one-time legacy Learn-identifier cleanup (roadmap 2.7).
@Suite("Legacy notification cleanup")
struct LegacyNotificationCleanupTests {

    private func request(_ identifier: String) -> UNNotificationRequest {
        UNNotificationRequest(identifier: identifier, content: UNMutableNotificationContent(), trigger: nil)
    }

    /// Isolated defaults so tests never see (or set) the real app flag.
    private func freshDefaults() -> UserDefaults {
        let suiteName = "legacy-cleanup-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    @Test func removesOnlyLegacyIdentifiers() {
        let center = FakeNotificationCenter()
        let uuid = UUID().uuidString
        let legacy = [
            "challenge_\(uuid)_123",
            "challenge_completion_\(uuid)",
            "learning_sleepScience_456",
            "streak_reminder_789",
            "snoozed_\(uuid)_321"
        ]
        let current = [
            "learn-challenge_\(uuid)_123",
            "learn-snoozed_\(uuid)_99",
            "alarm-\(uuid)-main-123-day2-standard",
            "alarm-\(uuid)-fu-1-456",
            "snooze-\(uuid)-789"
        ]
        for id in legacy + current { center.add(request(id), withCompletionHandler: nil) }

        LegacyNotificationCleanup.runOnce(center: center, defaults: freshDefaults())

        let remaining = center.pending.map(\.identifier).sorted()
        #expect(remaining == current.sorted())
    }

    @Test func runsOnlyOncePerInstall() {
        let center = FakeNotificationCenter()
        let defaults = freshDefaults()

        LegacyNotificationCleanup.runOnce(center: center, defaults: defaults)
        #expect(defaults.bool(forKey: LegacyNotificationCleanup.completedDefaultsKey))

        // A legacy request appearing after the flag is set must survive: the
        // cleanup is one-shot by design (current schemes can't collide with it).
        center.add(request("challenge_late_arrival"), withCompletionHandler: nil)
        LegacyNotificationCleanup.runOnce(center: center, defaults: defaults)
        #expect(center.pending.map(\.identifier) == ["challenge_late_arrival"])
    }

    @Test func flagIsSetEvenWhenNothingToRemove() {
        let center = FakeNotificationCenter()
        let defaults = freshDefaults()
        center.add(request("learn-challenge_current"), withCompletionHandler: nil)

        LegacyNotificationCleanup.runOnce(center: center, defaults: defaults)

        #expect(defaults.bool(forKey: LegacyNotificationCleanup.completedDefaultsKey))
        #expect(center.pending.count == 1)
    }
}
