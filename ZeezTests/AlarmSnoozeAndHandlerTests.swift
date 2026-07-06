import Testing
import Foundation
import UserNotifications
import CoreData
@testable import Zeez

/// Snooze + notification-handler scheduling tests (roadmap 2.4 step 1: the
/// `AlarmNotificationScheduling` injection extended beyond AlarmScheduler to
/// AlarmNotificationUtils and AlarmNotificationHandler).
///
/// AlarmNotificationUtils is a namespace enum, so its seams are static —
/// this suite is `.serialized` and every test restores the previous values.
@Suite("Snooze and handler scheduling", .serialized)
struct AlarmSnoozeAndHandlerTests {

    /// Runs `body` with Utils pointed at a fake center + in-memory container.
    private func withUtilsSeams<T>(
        _ body: (FakeNotificationCenter, PersistenceController) async throws -> T
    ) async rethrows -> T {
        let fake = FakeNotificationCenter()
        let controller = PersistenceController(inMemory: true)
        let previousCenter = AlarmNotificationUtils.notificationCenter
        let previousContainer = AlarmNotificationUtils.container
        AlarmNotificationUtils.notificationCenter = fake
        AlarmNotificationUtils.container = controller.container
        defer {
            AlarmNotificationUtils.notificationCenter = previousCenter
            AlarmNotificationUtils.container = previousContainer
        }
        return try await body(fake, controller)
    }

    private func snoozes(_ fake: FakeNotificationCenter, _ id: String) -> [UNNotificationRequest] {
        fake.pending.filter { $0.identifier.hasPrefix("snooze-\(id)-") }
    }

    private func snoozeChain(_ fake: FakeNotificationCenter, _ id: String) -> [UNNotificationRequest] {
        fake.pending.filter { $0.identifier.contains("alarm-\(id)-fu-snz-") }
    }

    // MARK: - Snooze (AlarmNotificationUtils)

    @Test func snoozeSchedulesAlarmConfiguredDurationAndPreArmedChain() async throws {
        try await withUtilsSeams { fake, controller in
            let alarm = try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, days: [2])
            let id = alarm.id!.uuidString

            AlarmNotificationUtils.scheduleSnooze(for: id)

            // Snooze fire uses the alarm's configured 9 minutes.
            try await AlarmTestSupport.waitUntil("snooze request") {
                self.snoozes(fake, id).count == 1
            }
            let snooze = try #require(snoozes(fake, id).first)
            let trigger = try #require(snooze.trigger as? UNTimeIntervalNotificationTrigger)
            #expect(trigger.timeInterval == 9 * 60)
            #expect(snooze.content.userInfo["type"] as? String == "main",
                    "Snooze fire must count as a main so follow-ups re-arm")

            // A follow-up chain is pre-armed BEHIND the snooze so Heavy Sleeper
            // works when the snooze fires with the app killed (1.1).
            try await AlarmTestSupport.waitUntil("pre-armed snooze chain") {
                self.snoozeChain(fake, id).count == AlarmNotificationUtils.maxPreScheduledFollowUps
            }
            for request in snoozeChain(fake, id) {
                let chainTrigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
                #expect(chainTrigger.timeInterval > 9 * 60,
                        "Chain entries fire after the snooze itself")
            }
        }
    }

    @Test func snoozeForUnknownAlarmFallsBackToBasicSnooze() async throws {
        try await withUtilsSeams { fake, _ in
            let ghostID = UUID().uuidString

            AlarmNotificationUtils.scheduleSnooze(for: ghostID, minutes: 5)

            try await AlarmTestSupport.waitUntil("basic snooze") {
                self.snoozes(fake, ghostID).count == 1
            }
            let snooze = try #require(snoozes(fake, ghostID).first)
            let trigger = try #require(snooze.trigger as? UNTimeIntervalNotificationTrigger)
            #expect(trigger.timeInterval == 5 * 60)
            #expect(snoozeChain(fake, ghostID).isEmpty,
                    "No chain without alarm settings to derive it from")
        }
    }

    @Test func snoozeCancelsThePendingFollowUpsItSupersedes() async throws {
        try await withUtilsSeams { fake, controller in
            let alarm = try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, days: [3])
            let id = alarm.id!.uuidString

            // Simulate an in-flight chain from the fire that is being snoozed.
            for n in 1...4 {
                fake.add(UNNotificationRequest(
                    identifier: "alarm-\(id)-fu-\(n)-999",
                    content: UNMutableNotificationContent(),
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(n) * 60, repeats: false)
                ), withCompletionHandler: nil)
            }

            AlarmNotificationUtils.scheduleSnooze(for: id)

            try await AlarmTestSupport.waitUntil("old chain gone, snooze armed") {
                let oldChain = fake.pending.filter { $0.identifier.hasPrefix("alarm-\(id)-fu-") && !$0.identifier.contains("-fu-snz-") }
                return oldChain.isEmpty && self.snoozes(fake, id).count == 1
            }
        }
    }

    // MARK: - Handler follow-ups (AlarmNotificationHandler)

    @Test func handlerSchedulesDynamicChainAtCadenceThroughInjectedCenter() async throws {
        let fake = FakeNotificationCenter()
        let controller = PersistenceController(inMemory: true)
        let handler = AlarmNotificationHandler(notificationCenter: fake, container: controller.container)
        let id = UUID().uuidString

        handler.scheduleFollowUps(alarmId: id, cadence: 60, maxCount: 6, snapshot: nil)

        try await AlarmTestSupport.waitUntil("6 dynamic follow-ups") {
            fake.pending.filter { $0.identifier.hasPrefix("alarm-\(id)-fu-") }.count == 6
        }
        let intervals = fake.pending
            .filter { $0.identifier.hasPrefix("alarm-\(id)-fu-") }
            .compactMap { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval }
            .sorted()
        #expect(intervals == [60, 120, 180, 240, 300, 360])
    }

    @Test func handlerCancelFollowUpsRemovesOnlyThatAlarmsChain() async throws {
        let fake = FakeNotificationCenter()
        let controller = PersistenceController(inMemory: true)
        let handler = AlarmNotificationHandler(notificationCenter: fake, container: controller.container)
        let victim = UUID().uuidString
        let bystander = UUID().uuidString

        handler.scheduleFollowUps(alarmId: victim, cadence: 60, maxCount: 4, snapshot: nil)
        handler.scheduleFollowUps(alarmId: bystander, cadence: 60, maxCount: 4, snapshot: nil)
        try await AlarmTestSupport.waitUntil("both chains armed") {
            fake.pending.filter { $0.identifier.contains("-fu-") }.count == 8
        }

        handler.cancelFollowUps(for: victim)

        try await AlarmTestSupport.waitUntil("victim chain removed, bystander intact") {
            fake.pending.filter { $0.identifier.contains("alarm-\(victim)-fu-") }.isEmpty &&
            fake.pending.filter { $0.identifier.contains("alarm-\(bystander)-fu-") }.count == 4
        }
    }
}
