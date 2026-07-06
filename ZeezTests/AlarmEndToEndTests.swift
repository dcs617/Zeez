import Testing
import Foundation
import UserNotifications
import CoreData
@testable import Zeez

/// End-to-end alarm scheduling tests (rewritten for roadmap 2.4).
///
/// The original suite ran against `PersistenceController.shared` (the live
/// simulator store), the real `UNUserNotificationCenter`, fixed `Task.sleep`
/// waits, and an identifier scheme that no longer exists — it failed en masse
/// and needed notification permission. This version uses an in-memory store,
/// the injected `FakeNotificationCenter`, and confirmation-based waiting.
@Suite("Alarm end-to-end scheduling")
struct AlarmEndToEndTests {

    private func mains(_ fake: FakeNotificationCenter, _ id: String) -> [UNNotificationRequest] {
        fake.pending.filter { $0.identifier.hasPrefix("alarm-\(id)-main-") }
    }

    private func allRequests(_ fake: FakeNotificationCenter, _ id: String) -> [UNNotificationRequest] {
        fake.pending.filter { $0.identifier.contains(id) }
    }

    // MARK: - Creation and scheduling

    @Test func basicAlarmSchedulesRepeatingWeekdayMain() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, days: [2])
        let id = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)

        try await AlarmTestSupport.waitUntil("one main") { self.mains(fake, id).count == 1 }
        let main = try #require(mains(fake, id).first)
        let trigger = try #require(main.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.weekday == 2)
        #expect(main.content.userInfo["type"] as? String == "main")
        #expect(main.content.userInfo["alarmID"] as? String == id)
    }

    @Test func multiDayAlarmSchedulesOneMainPerSelectedDay() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let weekdays: Set<Int> = [2, 3, 4, 5, 6]
        let alarm = try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, days: weekdays)
        let id = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)

        try await AlarmTestSupport.waitUntil("5 mains") { self.mains(fake, id).count == 5 }
        let scheduledDays = Set(mains(fake, id).compactMap {
            ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.weekday
        })
        #expect(scheduledDays == weekdays)
    }

    @Test func gentlePreAlarmSchedulesQuieterPreAlertPlusBackup() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)

        // Fixed 08:30 so the 30-minute pre-alert lands at 08:00 (no midnight wrap).
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 8; comps.minute = 30
        let alarmTime = Calendar.current.date(from: comps)!
        let alarm = try AlarmTestSupport.makeAlarm(
            in: controller.container.viewContext,
            time: alarmTime, days: [4], smartWake: true, smartWakeWindow: 30
        )
        let id = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)

        try await AlarmTestSupport.waitUntil("pre-alert + backup") { self.mains(fake, id).count == 2 }
        let preAlert = try #require(mains(fake, id).first { $0.identifier.hasSuffix("smart") })
        let backup = try #require(mains(fake, id).first { $0.identifier.hasSuffix("standard") })

        let preTrigger = try #require(preAlert.trigger as? UNCalendarNotificationTrigger)
        #expect(preTrigger.dateComponents.hour == 8)
        #expect(preTrigger.dateComponents.minute == 0)
        // The gentle pre-alarm is deliberately quieter (1.7): time-sensitive, never critical.
        #expect(preAlert.content.interruptionLevel == .timeSensitive)

        let backupTrigger = try #require(backup.trigger as? UNCalendarNotificationTrigger)
        #expect(backupTrigger.dateComponents.hour == 8)
        #expect(backupTrigger.dateComponents.minute == 30)
    }

    // MARK: - Modification

    @Test func editingAlarmTimeReschedulesToNewTime() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try AlarmTestSupport.makeAlarm(in: context, days: [3])
        let id = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)
        try await AlarmTestSupport.waitUntil("initial main") { self.mains(fake, id).count == 1 }

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 14; comps.minute = 45
        let newTime = Calendar.current.date(from: comps)!
        try context.performAndWait {
            alarm.time = newTime
            alarm.modifiedAt = Date()
            try context.save()
        }
        scheduler.scheduleSpecificAlarm(alarm)

        try await AlarmTestSupport.waitUntil("trigger moved to 14:45") {
            let triggers = self.mains(fake, id).compactMap { $0.trigger as? UNCalendarNotificationTrigger }
            return triggers.count == 1 &&
                   triggers[0].dateComponents.hour == 14 &&
                   triggers[0].dateComponents.minute == 45
        }
    }

    @Test func disablingRemovesRequestsAndReenablingRestoresThem() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try AlarmTestSupport.makeAlarm(in: context, days: [5])
        let id = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)
        try await AlarmTestSupport.waitUntil("scheduled") { !self.allRequests(fake, id).isEmpty }

        try context.performAndWait {
            alarm.enabled = false
            try context.save()
        }
        scheduler.scheduleSpecificAlarm(alarm)
        try await AlarmTestSupport.waitUntil("all requests removed") { self.allRequests(fake, id).isEmpty }

        try context.performAndWait {
            alarm.enabled = true
            try context.save()
        }
        scheduler.scheduleSpecificAlarm(alarm)
        try await AlarmTestSupport.waitUntil("restored") { self.mains(fake, id).count == 1 }
    }

    // MARK: - Deletion

    @Test func deletedAlarmLosesItsRequestsOnFullRescheduleWhileOthersSurvive() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)

        let doomed = try AlarmTestSupport.makeAlarm(in: context, name: "Doomed", days: [2])
        let keeper = try AlarmTestSupport.makeAlarm(in: context, name: "Keeper", days: [6])
        let doomedID = doomed.id!.uuidString
        let keeperID = keeper.id!.uuidString

        scheduler.scheduleAllAlarms(context: context)
        try await AlarmTestSupport.waitUntil("both scheduled") {
            self.mains(fake, doomedID).count == 1 && self.mains(fake, keeperID).count == 1
        }

        try context.performAndWait {
            context.delete(doomed)
            try context.save()
        }
        scheduler.scheduleAllAlarms(context: context)

        try await AlarmTestSupport.waitUntil("doomed removed, keeper kept") {
            self.allRequests(fake, doomedID).isEmpty && self.mains(fake, keeperID).count == 1
        }
    }

    // MARK: - Test notification

    @Test func testNotificationSchedules() async throws {
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)

        scheduler.scheduleTestNotification()

        try await AlarmTestSupport.waitUntil("test-notification present") {
            fake.pending.contains { $0.identifier == "test-notification" }
        }
    }

    // MARK: - Volume

    @Test func tenAlarmsAllGetScheduled() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)

        var ids: [String] = []
        for i in 0..<10 {
            let alarm = try AlarmTestSupport.makeAlarm(
                in: context, name: "Volume \(i)",
                time: Date().addingTimeInterval(Double(i + 1) * 3600),
                days: [(i % 7) + 1]
            )
            ids.append(alarm.id!.uuidString)
        }

        scheduler.scheduleAllAlarms(context: context)

        try await AlarmTestSupport.waitUntil("all 10 alarms have a main") {
            ids.allSatisfy { self.mains(fake, $0).count == 1 }
        }
    }

    @Test func rapidModificationsConvergeToTheFinalTime() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try AlarmTestSupport.makeAlarm(in: context, days: [7])
        let id = alarm.id!.uuidString

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        for i in 1...5 {
            comps.hour = 6 + i; comps.minute = 10 * i
            let newTime = Calendar.current.date(from: comps)!
            try context.performAndWait {
                alarm.time = newTime
                alarm.modifiedAt = Date()
                try context.save()
            }
            scheduler.scheduleSpecificAlarm(alarm)
        }

        // Final state: exactly one main at the last written time (11:50).
        try await AlarmTestSupport.waitUntil("converged to 11:50") {
            let triggers = self.mains(fake, id).compactMap { $0.trigger as? UNCalendarNotificationTrigger }
            return triggers.count == 1 &&
                   triggers[0].dateComponents.hour == 11 &&
                   triggers[0].dateComponents.minute == 50
        }
    }
}
