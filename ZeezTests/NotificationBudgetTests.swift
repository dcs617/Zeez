import Testing
import CoreData
import UserNotifications
@testable import Zeez

/// Tests for the 64-request budget accounting and the chain gate (roadmap 1.4).
@Suite("Notification budget")
struct NotificationBudgetTests {

    private func request(_ identifier: String) -> UNNotificationRequest {
        UNNotificationRequest(identifier: identifier, content: UNMutableNotificationContent(), trigger: nil)
    }

    @Test func categorizesIdentifiersByScheme() {
        let uuid = UUID().uuidString
        let requests = [
            request("alarm-\(uuid)-main-123-day2-standard"),
            request("alarm-\(uuid)-main-123-day3-smart"),
            request("alarm-\(uuid)-fu-1-456"),
            request("alarm-\(uuid)-fu-pre-2-456"),
            request("alarm-\(uuid)-fu-snz-3-456"),
            request("snooze-\(uuid)-789"),
            request("learn-daily-reminder"),
            request("test-notification")
        ]

        let budget = NotificationBudget(requests: requests)
        #expect(budget.mains == 2)
        #expect(budget.followUps == 3)
        #expect(budget.snoozes == 1)
        #expect(budget.other == 2)
        #expect(budget.total == 8)
        #expect(budget.remaining == NotificationBudget.systemCap - 8)
        #expect(!budget.isNearCap)
    }

    @Test func nearCapBoundary() {
        let below = NotificationBudget(requests: (0..<53).map { request("x-\($0)") })
        #expect(!below.isNearCap) // remaining 11 > 10

        let at = NotificationBudget(requests: (0..<54).map { request("x-\($0)") })
        #expect(at.isNearCap) // remaining 10

        let over = NotificationBudget(requests: (0..<70).map { request("x-\($0)") })
        #expect(over.remaining == 0)
        #expect(over.isNearCap)
    }

    @Test func canFitKeepsTheSafetyMargin() {
        // 54 pending + 6 chain + 4 margin = 64 → exactly fits
        let fits = NotificationBudget(requests: (0..<54).map { request("x-\($0)") })
        #expect(fits.canFit(6))

        // 55 pending + 6 + 4 = 65 → does not fit
        let tight = NotificationBudget(requests: (0..<55).map { request("x-\($0)") })
        #expect(!tight.canFit(6))
    }

    @Test func chainIsSkippedWhenBudgetIsTightButMainStillSchedules() async throws {
        let controller = PersistenceController(inMemory: true)
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)

        // Fill the fake near the cap: 58 unrelated requests. The main (1) fits;
        // the 6-entry chain would need 59 + 6 + 4 margin > 64 → must be skipped.
        for n in 0..<58 {
            fake.add(request("learn-filler-\(n)"), withCompletionHandler: nil)
        }

        let context = controller.container.viewContext
        var alarm: AlarmConfiguration!
        try context.performAndWait {
            alarm = AlarmConfiguration(context: context)
            alarm.id = UUID()
            alarm.name = "Budget fixture"
            alarm.enabled = true
            alarm.time = Date().addingTimeInterval(3600)
            alarm.daysOfWeek = try JSONEncoder().encode(Set([2]))
            try context.save()
        }
        let alarmID = alarm.id!.uuidString

        scheduler.scheduleSpecificAlarm(alarm)

        // Wait for the main to land, then confirm no chain ever appears.
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if fake.pending.contains(where: { $0.identifier.contains("alarm-\(alarmID)-main-") }) { break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(fake.pending.contains { $0.identifier.contains("alarm-\(alarmID)-main-") },
                "Main alarm must schedule even when the budget is tight")

        try await Task.sleep(nanoseconds: 500_000_000)
        let chain = fake.pending.filter { $0.identifier.contains("alarm-\(alarmID)-fu-pre-") }
        #expect(chain.isEmpty, "Chain must be skipped when it would blow the budget")
    }
}
