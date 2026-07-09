import Testing
import CoreData
import UserNotifications
@testable import Zeez

/// Regression guard for the second-audit C3 finding.
///
/// `scheduleAllSnapshots` took an `isSchedulingInProgress` flag and *returned* when a
/// second full reschedule arrived mid-flight. The dropped request was not retried, so an
/// alarm edited while launch rescheduling was still running stayed unscheduled until some
/// unrelated event triggered another reschedule — a silent, stale-state window on exactly
/// the path (app launch) where a concurrent edit is most likely.
///
/// A mid-flight request is now coalesced into a trailing rerun. Last writer wins, because
/// every run rewrites all alarm-owned notifications from scratch.
///
/// `FakeNotificationCenter.holdPendingRequests` is what makes the race observable: the
/// scheduler does all of its work inside the `getPendingNotificationRequests` completion,
/// so capturing that completion pins a run mid-flight.
@Suite("Full-reschedule coalescing (C3)", .serialized)
struct AlarmRescheduleCoalescingTests {

    private func mainIDs(_ fake: FakeNotificationCenter, alarmID: String) -> [String] {
        fake.pending.map(\.identifier).filter { $0.contains("alarm-\(alarmID)-main-") }
    }

    @Test func aRescheduleArrivingMidFlightIsRerunRatherThanDropped() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)

        let first = try AlarmTestSupport.makeAlarm(in: context, name: "First", days: [2])
        let firstID = try #require(first.id?.uuidString)

        // Pin run 1 inside its getPendingNotificationRequests completion.
        fake.holdPendingRequests = true
        scheduler.scheduleAllAlarms(context: context)
        try await AlarmTestSupport.waitUntil("run 1 to reach the notification center") {
            fake.isHoldingPendingRequests
        }

        // A second alarm is enabled and a full reschedule lands while run 1 is stuck.
        let second = try AlarmTestSupport.makeAlarm(in: context, name: "Second", days: [3])
        let secondID = try #require(second.id?.uuidString)
        scheduler.scheduleAllAlarms(context: context)

        // Give the queued request time to be observed and coalesced before releasing.
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(fake.pending.isEmpty, "Run 2 must wait behind run 1, not schedule anything of its own")

        fake.releaseHeldPendingRequests()

        // The trailing rerun schedules the alarm that run 1 never saw. Before C3 this
        // request was dropped and `Second` was never scheduled at all.
        try await AlarmTestSupport.waitUntil("the queued reschedule to run") {
            !self.mainIDs(fake, alarmID: secondID).isEmpty
        }
        #expect(!mainIDs(fake, alarmID: firstID).isEmpty, "The first alarm survives the rerun")
    }

    @Test func severalMidFlightRequestsCollapseIntoOneRerun() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let fake = FakeNotificationCenter()
        let scheduler = AlarmScheduler(notificationCenter: fake)

        let alarm = try AlarmTestSupport.makeAlarm(in: context, name: "Only", days: [2])
        let alarmID = try #require(alarm.id?.uuidString)

        fake.holdPendingRequests = true
        scheduler.scheduleAllAlarms(context: context)
        try await AlarmTestSupport.waitUntil("run 1 to reach the notification center") {
            fake.isHoldingPendingRequests
        }

        // Three edits land while run 1 is in flight. They must coalesce into one rerun,
        // not queue three: each pass rewrites every alarm-owned notification anyway.
        for _ in 0..<3 { scheduler.scheduleAllAlarms(context: context) }
        try await Task.sleep(nanoseconds: 200_000_000)

        fake.releaseHeldPendingRequests()

        // Run 1 starts with an empty center, so it clears nothing. The trailing rerun
        // finds run 1's notifications and clears them — one removal, one rerun.
        try await AlarmTestSupport.waitUntil("the coalesced rerun to clear run 1's requests") {
            fake.removeCalls == 1
        }

        // Settle well past any further pass, then confirm none was queued behind it.
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(fake.removeCalls == 1, "Three mid-flight requests must collapse into exactly one trailing rerun")
        #expect(!mainIDs(fake, alarmID: alarmID).isEmpty)
    }
}
