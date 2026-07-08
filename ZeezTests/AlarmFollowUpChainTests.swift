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

    // Uses the shared FakeNotificationCenter from AlarmTestSupport.swift.

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

    /// Confirmation-based waiting on the fake (no fixed sleeps). Returns as
    /// soon as the predicate holds — never re-evaluates after a successful
    /// loop exit (remove-then-add makes counts transiently dip).
    private func waitUntil(_ what: String, timeout: TimeInterval = 10,
                           _ predicate: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return }
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

    /// Seeds a pre-armed chain entry as `armFollowUpChain` would have left it,
    /// with a caller-chosen stamp (the next-fire epoch embedded in the ID).
    private func seedChainEntry(_ fake: FakeNotificationCenter, alarmID: String, n: Int, stamp: Int) {
        let content = UNMutableNotificationContent()
        content.userInfo = ["alarmID": alarmID, "type": "fu"]
        fake.add(
            UNNotificationRequest(
                identifier: "alarm-\(alarmID)-fu-pre-\(n)-\(stamp)",
                content: content,
                trigger: nil
            ),
            withCompletionHandler: nil
        )
    }

    private func trailingStamp(_ id: String) -> Double? {
        id.split(separator: "-").last.flatMap { Double($0) }
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
        try await waitUntil("chain replaced, not stacked, after settling") {
            self.chainIDs(fake, alarmID: alarmID).count == 6
        }
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

    // MARK: - Foreground re-arm of stale chains (second audit A6)

    @Test func foregroundRearmReplacesStaleChainWithNewStamp() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try makeAlarm(in: controller.container.viewContext, days: [2])
        let alarmID = alarm.id!.uuidString

        // The post-firing state: yesterday's chain entries, whose embedded
        // next-fire stamp has passed, with nothing armed for the next firing.
        let staleStamp = Int(Date().addingTimeInterval(-24 * 3600).timeIntervalSince1970)
        for n in 1...6 {
            seedChainEntry(fake, alarmID: alarmID, n: n, stamp: staleStamp)
        }

        let now = Date().timeIntervalSince1970
        scheduler.rearmStaleFollowUpChains(context: controller.container.viewContext)

        try await waitUntil("stale chain replaced by a future-stamped one") {
            let ids = self.chainIDs(fake, alarmID: alarmID)
            return ids.count == 6 && ids.allSatisfy { id in
                guard let stamp = self.trailingStamp(id) else { return false }
                return stamp > now
            }
        }
    }

    @Test func foregroundRearmLeavesCurrentChainUntouched() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try makeAlarm(in: controller.container.viewContext, days: [2])
        let alarmID = alarm.id!.uuidString

        // A future-stamped entry marks the chain as current. The stamp is
        // deliberately different from the alarm's real next-fire epoch, so a
        // spurious re-arm would show up as extra, differently-stamped entries.
        let futureStamp = Int(Date().addingTimeInterval(7200).timeIntervalSince1970) + 1
        seedChainEntry(fake, alarmID: alarmID, n: 1, stamp: futureStamp)

        scheduler.rearmStaleFollowUpChains(context: controller.container.viewContext)

        // Negative assertion — give the pipeline time to (wrongly) act.
        try await Task.sleep(nanoseconds: 1_000_000_000)
        #expect(chainIDs(fake, alarmID: alarmID) == ["alarm-\(alarmID)-fu-pre-1-\(futureStamp)"],
                "A chain armed for a future firing must not be re-armed on foreground")
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
