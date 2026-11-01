import Testing
import CoreData
import Foundation
import UserNotifications
@testable import Zeez

/// A recording ends just before the next alarm (decision 2026-10-29), so the alarm rings
/// exactly as it does without a recording. Before, nothing ended a recording but the user,
/// so it would still hold the microphone and the audio session when the alarm fired.
@Suite("Recording ends before the alarm", .serialized) @MainActor
struct RecordingAlarmBoundaryTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func pending(_ identifier: String, firesIn seconds: TimeInterval, from now: Date) -> AlarmHealth.PendingRequest {
        AlarmHealth.PendingRequest(identifier: identifier, nextFireDate: now.addingTimeInterval(seconds))
    }

    @Test("The recording ends a few seconds before the next main alarm")
    func endsBeforeTheMainAlarm() {
        let requests = [
            pending("alarm-A-main-1-day2-standard", firesIn: 8 * 3600, from: now),
            pending("alarm-B-main-1-day2-standard", firesIn: 7 * 3600, from: now)
        ]
        let end = RecordingAlarmBoundary.endTime(pending: requests, now: now)
        #expect(end == now.addingTimeInterval(7 * 3600 - RecordingAlarmBoundary.lead))
    }

    @Test("A snooze counts as a ring; follow-ups and other notifications do not")
    func snoozesCountFollowUpsDoNot() {
        let requests = [
            pending("alarm-A-fu-pre-1-123", firesIn: 3600, from: now),
            pending("learn-daily-reminder", firesIn: 1800, from: now),
            pending("snooze-A-123", firesIn: 2 * 3600, from: now),
            pending("alarm-A-main-1-day2-standard", firesIn: 6 * 3600, from: now)
        ]
        let end = RecordingAlarmBoundary.endTime(pending: requests, now: now)
        #expect(end == now.addingTimeInterval(2 * 3600 - RecordingAlarmBoundary.lead))
    }

    @Test("With no alarm pending, the recording keeps running")
    func noAlarmNoBoundary() {
        let requests = [pending("alarm-A-fu-pre-1-123", firesIn: 3600, from: now)]
        #expect(RecordingAlarmBoundary.endTime(pending: requests, now: now) == nil)
    }

    @Test("An alarm due within the lead ends the recording now, never in the past")
    func imminentAlarmEndsNow() {
        let requests = [pending("alarm-A-main-1-day2-standard", firesIn: 2, from: now)]
        #expect(RecordingAlarmBoundary.endTime(pending: requests, now: now) == now)
    }

    @Test("A running recording schedules its end for the alarm, and ends there")
    func controllerEndsTheRecordingAtTheBoundary() async throws {
        let persistence = PersistenceController(inMemory: true)
        let manager = SleepSessionManager(persistenceController: persistence, monitors: FakeSessionMonitors())
        let center = FakeNotificationCenter()
        let fire = Date().addingTimeInterval(2 * 3600)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
        center.add(UNNotificationRequest(identifier: "alarm-A-main-1-day2-standard",
                                         content: UNMutableNotificationContent(),
                                         trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)),
                   withCompletionHandler: nil)

        var clock = Date()
        let controller = SleepRecordingController(manager: manager, notificationCenter: center,
                                                  microphone: FakeMicrophonePermission(granted: true),
                                                  errors: ErrorManager(), now: { clock })

        let session: SleepSession = try await withCheckedThrowingContinuation { continuation in
            controller.start { continuation.resume(with: $0) }
        }
        try await AlarmTestSupport.waitUntil("the alarm boundary") { controller.alarmEndTime != nil }
        let boundary = try #require(controller.alarmEndTime)
        let expectedFire = try #require(Calendar.current.date(from: components))
        #expect(boundary == expectedFire.addingTimeInterval(-RecordingAlarmBoundary.lead))

        // The timer fires late, after the alarm itself: the recording still ends at the boundary.
        clock = expectedFire.addingTimeInterval(60)
        let outcome: SessionEndOutcome = try await withCheckedThrowingContinuation { continuation in
            controller.endForAlarm { continuation.resume(with: $0) }
        }
        guard case .saved = outcome else {
            Issue.record("Expected the recording to be saved, got \(outcome)")
            return
        }
        #expect(session.endTime == boundary)
        #expect(!session.isActive)
        #expect(controller.activeSession == nil)
    }
}
