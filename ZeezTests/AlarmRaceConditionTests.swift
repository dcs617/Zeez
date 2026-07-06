import Testing
import Foundation
import UserNotifications
import CoreData
@testable import Zeez

/// Concurrency tests (rewritten for roadmap 2.4) on the in-memory store +
/// injected fake center. The point is that concurrent scheduling converges
/// to a correct final state, not merely that nothing crashes.
@Suite("Alarm race conditions")
struct AlarmRaceConditionTests {

    private func mains(_ fake: FakeNotificationCenter, _ id: String) -> [UNNotificationRequest] {
        fake.pending.filter { $0.identifier.hasPrefix("alarm-\(id)-main-") }
    }

    @Test func concurrentSchedulingOfDistinctAlarmsSchedulesEachOnce() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)

        var alarms: [AlarmConfiguration] = []
        for i in 0..<5 {
            alarms.append(try AlarmTestSupport.makeAlarm(
                in: context, name: "Race \(i)",
                time: Date().addingTimeInterval(Double(i + 1) * 3600),
                days: [(i % 7) + 1]
            ))
        }
        let ids = alarms.map { $0.id!.uuidString }

        await withTaskGroup(of: Void.self) { group in
            for alarm in alarms {
                group.addTask { scheduler.scheduleSpecificAlarm(alarm) }
            }
        }

        try await AlarmTestSupport.waitUntil("each alarm scheduled exactly once") {
            ids.allSatisfy { self.mains(fake, $0).count == 1 }
        }
    }

    @Test func concurrentReschedulingOfTheSameAlarmDoesNotDuplicate() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try AlarmTestSupport.makeAlarm(in: context, days: [5])
        let id = alarm.id!.uuidString

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { scheduler.scheduleSpecificAlarm(alarm) }
            }
        }

        try await AlarmTestSupport.waitUntil("exactly one main after 10 concurrent passes") {
            self.mains(fake, id).count == 1
        }
        // Give any straggler pass time to land, then re-confirm no stacking.
        try await Task.sleep(nanoseconds: 500_000_000)
        try await AlarmTestSupport.waitUntil("still exactly one main after settling") {
            self.mains(fake, id).count == 1
        }
    }

    @Test func observerDebouncesRapidChangesIntoAConsistentReschedule() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let observer = AlarmObserver(scheduler: scheduler)
        defer { observer.reset() }

        observer.startObserving(context: context)

        let alarm = try AlarmTestSupport.makeAlarm(in: context, days: [6])
        let id = alarm.id!.uuidString

        // Rapid successive edits — the observer must debounce these into a
        // reschedule that converges on the final time.
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        for minute in [10, 20, 30] {
            comps.hour = 9; comps.minute = minute
            let time = Calendar.current.date(from: comps)!
            try context.performAndWait {
                alarm.time = time
                alarm.modifiedAt = Date()
                try context.save()
            }
        }

        try await AlarmTestSupport.waitUntil("debounced reschedule lands on 09:30", timeout: 15) {
            let triggers = self.mains(fake, id).compactMap { $0.trigger as? UNCalendarNotificationTrigger }
            return triggers.count == 1 &&
                   triggers[0].dateComponents.hour == 9 &&
                   triggers[0].dateComponents.minute == 30
        }
    }
}
