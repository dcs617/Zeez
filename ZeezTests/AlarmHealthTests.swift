import Testing
import Foundation
import UserNotifications
import CoreData
@testable import Zeez

/// `AlarmHealth` compares what the alarm list says should ring with what the notification
/// center actually holds (second-audit C5). The failure it exists to surface is silent: an
/// alarm switched on in Core Data with no pending main notification, which will not ring.
@Suite("Alarm health")
struct AlarmHealthTests {

    private static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let alarmA = "AAAAAAAA-0000-0000-0000-000000000001"
    private let alarmB = "BBBBBBBB-0000-0000-0000-000000000002"

    private func request(_ id: String, inHours hours: Double) -> AlarmHealth.PendingRequest {
        .init(identifier: id, nextFireDate: Self.now.addingTimeInterval(hours * 3600))
    }

    // MARK: - Status

    @Test("Every enabled alarm with a pending main is healthy, and the next ring is the earliest main")
    func scheduledAlarmsAreHealthy() {
        let health = AlarmHealth(
            pending: [
                request("alarm-\(alarmA)-main-1-day2-standard", inHours: 9),
                request("alarm-\(alarmA)-fu-1", inHours: 1),  // follow-ups don't ring on their own
                request("alarm-\(alarmB)-main-2-day3-standard", inHours: 30),
                request("learn-reminder-1", inHours: 2)
            ],
            enabledAlarmIDs: [alarmA, alarmB], authorization: .authorized, now: Self.now)

        #expect(health.status == .healthy)
        #expect(health.scheduledCount == 3, "Non-alarm requests are not alarm notifications")
        #expect(health.nextRingDate == Self.now.addingTimeInterval(9 * 3600))
    }

    @Test("An enabled alarm with no pending main is reported, even if its follow-ups remain")
    func alarmWithoutMainIsReported() {
        let health = AlarmHealth(
            pending: [
                request("alarm-\(alarmA)-main-1-day2-standard", inHours: 9),
                request("alarm-\(alarmB)-fu-1", inHours: 1)
            ],
            enabledAlarmIDs: [alarmA, alarmB], authorization: .authorized, now: Self.now)

        #expect(health.status == .alarmsNotScheduled(1))
        #expect(health.unscheduledAlarmIDs == [alarmB])
    }

    @Test("Without notification permission no alarm can ring, whatever is pending")
    func missingPermissionOutranksEverything() {
        for authorization in [UNAuthorizationStatus.denied, .notDetermined] {
            let health = AlarmHealth(
                pending: [request("alarm-\(alarmA)-main-1-day2-standard", inHours: 9)],
                enabledAlarmIDs: [alarmA, alarmB], authorization: authorization, now: Self.now)
            #expect(health.status == .notificationsOff)
        }
    }

    @Test("With no enabled alarms there is nothing to report")
    func noEnabledAlarms() {
        let health = AlarmHealth(pending: [], enabledAlarmIDs: [], authorization: .denied, now: Self.now)
        #expect(health.status == .noEnabledAlarms)
    }

    @Test("A pending snooze is the next ring; past fire dates are ignored")
    func snoozeCountsAndPastDatesAreIgnored() {
        let health = AlarmHealth(
            pending: [
                request("alarm-\(alarmA)-main-1-day2-standard", inHours: 9),
                request("snooze-\(alarmA)-123", inHours: 0.15),
                request("snooze-\(alarmA)-100", inHours: -1)
            ],
            enabledAlarmIDs: [alarmA], authorization: .authorized, now: Self.now)
        #expect(health.nextRingDate == Self.now.addingTimeInterval(0.15 * 3600))
    }

    // MARK: - Against the real scheduler

    @Test("An alarm the scheduler armed reads as healthy, with the scheduler's own next fire date")
    func schedulerOutputIsHealthy() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let alarm = try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, days: [2, 4])
        let id = alarm.id!.uuidString
        let expectedNext = try controller.container.viewContext.performAndWait {
            try #require(AlarmSnapshot(alarm)?.nextFireDate())
        }

        scheduler.scheduleSpecificAlarm(alarm)
        try await AlarmTestSupport.waitUntil("two mains") {
            fake.pending.filter { $0.identifier.hasPrefix("alarm-\(id)-main-") }.count == 2
        }

        let health = AlarmHealth(pending: fake.pending.map(AlarmHealth.PendingRequest.init),
                                 enabledAlarmIDs: [id], authorization: .authorized)
        #expect(health.status == .healthy)
        let next = try #require(health.nextRingDate)
        #expect(abs(next.timeIntervalSince(expectedNext)) < 60)
    }

    /// The scheduler refuses an enabled alarm with no selected days ("missing required data")
    /// and only logs it. The list still shows the alarm as on; this is the screen that says so.
    @Test("An enabled alarm the scheduler refused is reported as not scheduled")
    func refusedAlarmIsReported() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)
        let good = try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, days: [2])
        let refused = try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, days: [])

        scheduler.scheduleSpecificAlarm(good)
        scheduler.scheduleSpecificAlarm(refused)
        let goodID = good.id!.uuidString
        try await AlarmTestSupport.waitUntil("good alarm scheduled") {
            fake.pending.contains { $0.identifier.hasPrefix("alarm-\(goodID)-main-") }
        }

        let health = AlarmHealth(pending: fake.pending.map(AlarmHealth.PendingRequest.init),
                                 enabledAlarmIDs: [goodID, refused.id!.uuidString],
                                 authorization: .authorized)
        #expect(health.status == .alarmsNotScheduled(1))
        #expect(health.unscheduledAlarmIDs == [refused.id!.uuidString])
    }
}
