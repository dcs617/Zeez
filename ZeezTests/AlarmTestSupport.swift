import Foundation
import Testing
import CoreData
import UserNotifications
@testable import Zeez

/// In-memory stand-in for UNUserNotificationCenter (roadmap 2.4). Thread-safe;
/// adding a request replaces any same-identifier entry, like the real center.
/// Shared by every alarm suite so tests run without notification permission,
/// the real center, or the shared simulator store.
final class FakeNotificationCenter: AlarmNotificationScheduling, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UNNotificationRequest] = []

    /// What `criticalAlertsEnabled` reports; tests can flip it.
    var criticalEnabled = false

    var pending: [UNNotificationRequest] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?) {
        lock.lock()
        storage.removeAll { $0.identifier == request.identifier }
        storage.append(request)
        lock.unlock()
        completionHandler?(nil)
    }

    func getPendingNotificationRequests(completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void) {
        completionHandler(pending)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        lock.lock()
        storage.removeAll { identifiers.contains($0.identifier) }
        lock.unlock()
    }

    func getNotificationSettings(completionHandler: @escaping @Sendable (UNNotificationSettings) -> Void) {
        // UNNotificationSettings cannot be constructed in tests; paths that
        // need settings use criticalAlertsEnabled instead.
    }

    func criticalAlertsEnabled(completionHandler: @escaping @Sendable (Bool) -> Void) {
        completionHandler(criticalEnabled)
    }
}

enum AlarmTestSupport {

    /// Creates and saves an AlarmConfiguration fixture on the context's queue.
    @discardableResult
    static func makeAlarm(in context: NSManagedObjectContext,
                          name: String = "Test fixture",
                          time: Date? = Date().addingTimeInterval(3600),
                          days: Set<Int> = [2],
                          enabled: Bool = true,
                          heavySleeper: Bool = false,
                          smartWake: Bool = false,
                          smartWakeWindow: Int16 = 30) throws -> AlarmConfiguration {
        var alarm: AlarmConfiguration!
        try context.performAndWait {
            alarm = AlarmConfiguration(context: context)
            alarm.id = UUID()
            alarm.name = name
            alarm.enabled = enabled
            alarm.time = time
            alarm.daysOfWeek = try JSONEncoder().encode(days)
            alarm.heavySleeperMode = heavySleeper
            alarm.smartWakeEnabled = smartWake
            alarm.smartWakeWindow = smartWakeWindow
            alarm.snoozeEnabled = true
            alarm.snoozeDuration = 9
            alarm.createdAt = Date()
            alarm.modifiedAt = Date()
            try context.save()
        }
        return alarm
    }

    /// Confirmation-based waiting on an arbitrary condition — replaces the
    /// fixed `Task.sleep` waits that made the legacy suites slow and flaky.
    /// Returns as soon as the predicate holds; the failure path evaluates it
    /// exactly once more (never re-evaluate after a successful loop exit —
    /// remove-then-add scheduling makes counts transiently dip).
    static func waitUntil(_ what: String, timeout: TimeInterval = 10,
                          _ predicate: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(predicate(), "Timed out waiting for \(what)")
    }
}
