import Testing
import CoreData
import UserNotifications
@testable import Zeez

/// Tests for the pre-scheduled follow-up chain (roadmap 1.1): chains are
/// armed at alarm-scheduling time — not in `willPresent` — so Heavy Sleeper
/// works with the app killed. Uses a fake notification center injected via
/// `AlarmNotificationScheduling`, so no notification permission is needed.
@Suite("Pre-scheduled follow-up chains", .serialized)
struct AlarmFollowUpChainTests {

    // MARK: - Fake center

    final class FakeNotificationCenter: AlarmNotificationScheduling, @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [UNNotificationRequest] = []

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
            // Not exercised by the scheduling paths under test.
        }
    }

    // MARK: - Helpers

    private func makeAlarm(in context: NSManagedObjectContext,
                           days: Set<Int>,
                           heavySleeper: Bool = false,
                           enabled: Bool = true) throws -> AlarmConfiguration {
        var alarm: AlarmConfiguration!
        try context.performAndWait {
            alarm = AlarmConfiguration(context: context)
            alarm.id = UUID()
            alarm.name = "Chain fixture"
            alarm.enabled = enabled
            alarm.time = Date().addingTimeInterval(3600)
            alarm.daysOfWeek = try JSONEncoder().encode(days)
            alarm.heavySleeperMode = heavySleeper
            alarm.smartWakeEnabled = false
            try context.save()
        }
        return alarm
    }

    /// Confirmation-based waiting on the fake (no fixed sleeps).
    private func waitUntil(_ what: String, timeout: TimeInterval = 10,
                           _ predicate: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(predicate(), "Timed out waiting for \(what)")
    }

    private func chainIDs(_ fake: FakeNotificationCenter, alarmID: String) -> [String] {
        fake.pending.map(\.identifier).filter { $0.contains("alarm-\(alarmID)-fu-pre-") }
    }

    private func mainIDs(_ fake: FakeNotificationCenter, alarmID: String) -> [String] {
        fake.pending.map(\.identifier).filter { $0.contains("alarm-\(alarmID)-main-") }
    }

    // MARK: - Tests

    @Test func schedulingAnAlarmPreArmsTheFollowUpChain() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try makeAlarm(in: controller.container.viewContext, days: [2])
        let alarmID = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)

        try await waitUntil("main + 6 pre-armed follow-ups") {
            self.mainIDs(fake, alarmID: alarmID).count == 1 &&
            self.chainIDs(fake, alarmID: alarmID).count == 6
        }

        // Chain triggers are one-shot absolute-time triggers at
        // nextFire + n * cadence (60s in normal mode).
        var snapshot: AlarmSnapshot?
        controller.container.viewContext.performAndWait {
            snapshot = AlarmSnapshot(alarm)
        }
        let snap = try #require(snapshot)
        let nextFire = try #require(snap.nextFireDate())
        let triggers = fake.pending
            .filter { $0.identifier.contains("-fu-pre-") }
            .compactMap { $0.trigger as? UNCalendarNotificationTrigger }
        #expect(triggers.count == 6)
        for trigger in triggers {
            #expect(!trigger.repeats)
            let fire = try #require(trigger.nextTriggerDate())
            let offset = fire.timeIntervalSince(nextFire)
            #expect(offset >= 59 && offset <= 6 * 60 + 1,
                    "Chain fire should be within [1, 6] cadences past the main fire (got \(offset)s)")
        }
    }

    @Test func heavySleeperGetsLongerFasterChain() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try makeAlarm(in: controller.container.viewContext, days: [3], heavySleeper: true)
        let alarmID = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)

        try await waitUntil("8 heavy-sleeper follow-ups") {
            self.chainIDs(fake, alarmID: alarmID).count == 8
        }
    }

    @Test func chainIsArmedForNextFiringDayOnlyEvenWithSevenDayAlarms() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try makeAlarm(in: controller.container.viewContext, days: [1, 2, 3, 4, 5, 6, 7])
        let alarmID = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)

        try await waitUntil("7 mains") {
            self.mainIDs(fake, alarmID: alarmID).count == 7
        }
        try await waitUntil("exactly 6 chain entries (one day, not 42)") {
            self.chainIDs(fake, alarmID: alarmID).count == 6
        }
    }

    @Test func reschedulingReplacesTheChainInsteadOfStacking() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try makeAlarm(in: controller.container.viewContext, days: [2])
        let alarmID = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)
        try await waitUntil("first chain") {
            self.chainIDs(fake, alarmID: alarmID).count == 6
        }

        scheduler.scheduleSpecificAlarm(alarm)
        // Wait for the second pass to finish (a main re-add signals it ran),
        // then confirm the chain did not stack.
        try await waitUntil("second schedule pass") {
            self.mainIDs(fake, alarmID: alarmID).count == 1 &&
            self.chainIDs(fake, alarmID: alarmID).count == 6
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(chainIDs(fake, alarmID: alarmID).count == 6, "Chain must be replaced, not stacked")
    }

    @Test func disabledAlarmArmsNothing() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try makeAlarm(in: controller.container.viewContext, days: [2], enabled: false)
        let alarmID = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(mainIDs(fake, alarmID: alarmID).isEmpty)
        #expect(chainIDs(fake, alarmID: alarmID).isEmpty)
    }

    @Test func nextFireDatePicksEarliestSelectedWeekday() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let calendar = Calendar.current

        // Alarm at 07:30 on Monday(2) and Friday(6)
        var alarm: AlarmConfiguration!
        try context.performAndWait {
            alarm = AlarmConfiguration(context: context)
            alarm.id = UUID()
            alarm.enabled = true
            var comps = calendar.dateComponents([.year, .month, .day], from: Date())
            comps.hour = 7; comps.minute = 30
            alarm.time = calendar.date(from: comps)
            alarm.daysOfWeek = try JSONEncoder().encode(Set([2, 6]))
            try context.save()
        }

        var snapshot: AlarmSnapshot?
        context.performAndWait { snapshot = AlarmSnapshot(alarm) }
        let snap = try #require(snapshot)

        // From a Wednesday reference, the next fire must be Friday 07:30.
        let reference = try #require(calendar.nextDate(
            after: Date(), matching: DateComponents(hour: 12, weekday: 4), matchingPolicy: .nextTime))
        let next = try #require(snap.nextFireDate(after: reference, calendar: calendar))

        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: next)
        #expect(parts.weekday == 6)
        #expect(parts.hour == 7)
        #expect(parts.minute == 30)
        #expect(next > reference)
        #expect(next.timeIntervalSince(reference) < 7 * 24 * 3600)
    }
}
