import Testing
import Foundation
import UserNotifications
import CoreData
import UIKit
@testable import Zeez

/// Reliability and edge-case tests (rewritten for roadmap 2.4) on the
/// in-memory store + injected fake center — no shared simulator state,
/// no fixed sleeps, no notification permission.
@Suite("Alarm reliability")
struct AlarmReliabilityTests {

    private func mains(_ fake: FakeNotificationCenter, _ id: String) -> [UNNotificationRequest] {
        fake.pending.filter { $0.identifier.hasPrefix("alarm-\(id)-main-") }
    }

    private func allRequests(_ fake: FakeNotificationCenter, _ id: String) -> [UNNotificationRequest] {
        fake.pending.filter { $0.identifier.contains(id) }
    }

    // MARK: - Reschedule stability

    @Test func alarmSurvivesFullRescheduleAfterSpecificScheduling() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try AlarmTestSupport.makeAlarm(in: context, days: [3])
        let id = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)
        try await AlarmTestSupport.waitUntil("scheduled") { self.mains(fake, id).count == 1 }

        // App-restart / significantTimeChange path: a full reschedule must
        // leave the alarm scheduled exactly once (replaced, not dropped/duped).
        scheduler.scheduleAllAlarms(context: context)
        try await AlarmTestSupport.waitUntil("still exactly one main") {
            self.mains(fake, id).count == 1
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        try await AlarmTestSupport.waitUntil("one main after settling (no duplicates)") {
            self.mains(fake, id).count == 1
        }
    }

    @Test func repeatedFullReschedulesStayConsistent() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try AlarmTestSupport.makeAlarm(in: context, days: [4])
        let id = alarm.id!.uuidString

        for iteration in 1...5 {
            scheduler.scheduleAllAlarms(context: context)
            try await AlarmTestSupport.waitUntil("one main after pass \(iteration)") {
                self.mains(fake, id).count == 1
            }
        }
    }

    // MARK: - Volume + rapid churn

    @Test func twentyAlarmsScheduleAndDeleteCleanly() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)

        var alarms: [AlarmConfiguration] = []
        for i in 0..<20 {
            alarms.append(try AlarmTestSupport.makeAlarm(
                in: context, name: "Churn \(i)",
                time: Date().addingTimeInterval(Double(i + 1) * 300),
                days: [(i % 7) + 1]
            ))
        }
        let ids = alarms.map { $0.id!.uuidString }

        scheduler.scheduleAllAlarms(context: context)
        try await AlarmTestSupport.waitUntil("all 20 scheduled") {
            ids.allSatisfy { self.mains(fake, $0).count == 1 }
        }

        try context.performAndWait {
            alarms.forEach(context.delete)
            try context.save()
        }
        scheduler.scheduleAllAlarms(context: context)

        try await AlarmTestSupport.waitUntil("no alarm-owned requests remain") {
            ids.allSatisfy { self.allRequests(fake, $0).isEmpty }
        }
    }

    @Test func concurrentModificationDuringSchedulingEndsConsistent() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try AlarmTestSupport.makeAlarm(in: context, days: [2])
        let id = alarm.id!.uuidString

        // Kick off a schedule, mutate immediately, schedule again.
        scheduler.scheduleSpecificAlarm(alarm)
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 21; comps.minute = 15
        let finalTime = Calendar.current.date(from: comps)!
        try context.performAndWait {
            alarm.time = finalTime
            alarm.modifiedAt = Date()
            try context.save()
        }
        scheduler.scheduleSpecificAlarm(alarm)

        try await AlarmTestSupport.waitUntil("consistent final state (21:15, one main)") {
            let triggers = self.mains(fake, id).compactMap { $0.trigger as? UNCalendarNotificationTrigger }
            return triggers.count == 1 &&
                   triggers[0].dateComponents.hour == 21 &&
                   triggers[0].dateComponents.minute == 15
        }
    }

    // MARK: - Edge cases

    @Test func alarmAtCurrentTimeStillSchedules() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        // Repeating weekday triggers roll to next week automatically.
        let alarm = try AlarmTestSupport.makeAlarm(
            in: controller.container.viewContext,
            time: Date(),
            days: [Calendar.current.component(.weekday, from: Date())]
        )
        let id = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)
        try await AlarmTestSupport.waitUntil("scheduled despite current-time alarm") {
            self.mains(fake, id).count == 1
        }
    }

    @Test func emptyDaysOfWeekSchedulesNothingWithoutCrashing() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, days: [])
        let id = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(allRequests(fake, id).isEmpty, "Empty days must schedule nothing")
    }

    @Test func nilTimeSchedulesNothingWithoutCrashing() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, time: nil, days: [2])
        let id = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(allRequests(fake, id).isEmpty, "nil time must schedule nothing")
    }

    @Test func memoryWarningDoesNotBlockScheduling() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)

        var ids: [String] = []
        for i in 0..<12 {
            let alarm = try AlarmTestSupport.makeAlarm(
                in: context, name: "Pressure \(i)",
                time: Date().addingTimeInterval(Double(i + 1) * 120),
                days: [(i % 7) + 1]
            )
            ids.append(alarm.id!.uuidString)
        }

        await MainActor.run {
            NotificationCenter.default.post(
                name: UIApplication.didReceiveMemoryWarningNotification, object: nil
            )
        }
        scheduler.scheduleAllAlarms(context: context)

        try await AlarmTestSupport.waitUntil("all scheduled under memory pressure") {
            ids.allSatisfy { self.mains(fake, $0).count == 1 }
        }
    }
}
