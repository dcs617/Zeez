import Testing
import Foundation
import CoreData
@testable import Zeez

/// The phone side of the watch data path (second-audit D2a). `fetchWatchPayloads` was rewritten
/// by A2/A5 and had no tests; it now runs against an in-memory store via `WatchPayloadBuilder`.
@Suite("Watch payload builder")
struct WatchPayloadBuilderTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private static let everyDay: Set<Int> = Set(1...7)

    private func snapshot(in context: NSManagedObjectContext, name: String, time: Date,
                          days: Set<Int> = everyDay, enabled: Bool = true) throws -> AlarmSnapshot {
        let alarm = try AlarmTestSupport.makeAlarm(in: context, name: name, time: time, days: days, enabled: enabled)
        return try context.performAndWait { try #require(AlarmSnapshot(alarm)) }
    }

    // MARK: - Next alarm

    /// `AlarmConfiguration.time` keeps whatever date the alarm was created on. The old fetch
    /// sorted on it, so an alarm set up last year at 06:00 beat one created today for 23:00 —
    /// even at 22:00, an hour before the 23:00 alarm rings.
    @Test("The next alarm is the next to ring, not the one with the oldest stored date")
    func nextAlarmIsNextToRing() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let morning = try snapshot(in: context, name: "Morning", time: date(2025, 1, 5, 6))
        let late = try snapshot(in: context, name: "Late", time: date(2026, 10, 12, 23))
        let now = date(2026, 10, 13, 22)

        let status = WatchPayloadBuilder.nextAlarmStatus(from: [morning, late], now: now, calendar: Self.calendar)
        #expect(status.alarmName == "Late")
        #expect(status.isEnabled)
        #expect(status.nextAlarmTime == date(2026, 10, 13, 23))
    }

    @Test("The wire carries the absolute next fire, so the watch countdown is in the future")
    func nextAlarmTimeIsUpcoming() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let alarm = try snapshot(in: context, name: "", time: date(2024, 3, 1, 7, 30))
        let now = date(2026, 10, 13, 22)

        let status = WatchPayloadBuilder.nextAlarmStatus(from: [alarm], now: now, calendar: Self.calendar)
        let next = try #require(status.nextAlarmTime)
        #expect(next > now)
        #expect(next == date(2026, 10, 14, 7, 30))
        #expect(status.alarmName == "Alarm", "An unnamed alarm shows as \"Alarm\", as its notification does")
    }

    @Test("Selected weekdays decide the next alarm")
    func weekdaysDecide() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        // 2026-10-13 is a Tuesday (weekday 3).
        let wednesdayOnly = try snapshot(in: context, name: "Wednesday", time: date(2026, 1, 1, 9), days: [4])
        let fridayEarly = try snapshot(in: context, name: "Friday", time: date(2026, 1, 1, 5), days: [6])
        let now = date(2026, 10, 13, 22)

        let status = WatchPayloadBuilder.nextAlarmStatus(from: [fridayEarly, wednesdayOnly], now: now, calendar: Self.calendar)
        #expect(status.alarmName == "Wednesday")
        #expect(status.nextAlarmTime == date(2026, 10, 14, 9))
    }

    @Test("With nothing able to ring, the status is explicitly disabled so the watch clears it")
    func nothingToRingIsDisabled() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let off = try snapshot(in: context, name: "Off", time: date(2026, 1, 1, 6), enabled: false)
        let noDays = try snapshot(in: context, name: "No days", time: date(2026, 1, 1, 6), days: [])

        let status = WatchPayloadBuilder.nextAlarmStatus(from: [off, noDays], now: date(2026, 10, 13, 22),
                                                         calendar: Self.calendar)
        #expect(!status.isEnabled)
        #expect(status.nextAlarmTime == nil)

        let decoded = try #require(WatchSyncEnvelope(dictionary: WatchSyncEnvelope(alarmStatus: status).toDictionary()).alarmStatus)
        #expect(!decoded.isEnabled, "The watch must receive the disabled status, not an empty envelope")
    }

    // MARK: - Against a store

    @Test("Fetch returns the latest completed session and the next alarm, decodable by the watch")
    func fetchBuildsWatchPayloads() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let now = Date()
        try context.performAndWait {
            for (hoursAgo, active) in [(30.0, false), (10.0, false), (1.0, true)] {
                let session = SleepSession(context: context)
                session.id = UUID()
                session.startTime = now.addingTimeInterval(-hoursAgo * 3600)
                session.endTime = active ? nil : now.addingTimeInterval(-(hoursAgo - 8) * 3600)
                session.isActive = active
                session.qualityScore = 1.0  // the no-estimate sentinel
            }
            try context.save()
        }
        try AlarmTestSupport.makeAlarm(in: context, name: "Wake", time: now.addingTimeInterval(-3 * 86_400 + 3600),
                                       days: Self.everyDay)

        let (summary, alarm) = await withCheckedContinuation { continuation in
            WatchPayloadBuilder.fetch(includeSleep: true, includeAlarm: true,
                                      container: controller.container, now: { now }) { summary, alarm in
                continuation.resume(returning: (summary, alarm))
            }
        }

        let sleep = try #require(summary)
        #expect(abs(sleep.lastNightDuration - 8 * 3600) < 1)
        #expect(sleep.bedTime.map { abs($0.timeIntervalSince(now.addingTimeInterval(-10 * 3600))) < 1 } == true,
                "The latest completed session wins; the active one is skipped")
        #expect(!sleep.isQualityScoreAvailable, "The sentinel must not reach the watch as a score")

        let status = try #require(alarm)
        #expect(status.isEnabled)
        let next = try #require(status.nextAlarmTime)
        #expect(next > now && next <= now.addingTimeInterval(86_400))

        let wire = WatchSyncEnvelope(dictionary: WatchSyncEnvelope(sleepSummary: summary, alarmStatus: alarm).toDictionary())
        #expect(wire.alarmStatus?.nextAlarmTime == next)
        #expect(wire.sleepSummary?.isQualityScoreAvailable == false)
    }

    @Test("Fetch omits what was not requested")
    func fetchHonoursIncludeFlags() async throws {
        let controller = PersistenceController(inMemory: true)
        try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, days: Self.everyDay)

        let (summary, alarm) = await withCheckedContinuation { continuation in
            WatchPayloadBuilder.fetch(includeSleep: true, includeAlarm: false,
                                      container: controller.container) { summary, alarm in
                continuation.resume(returning: (summary, alarm))
            }
        }
        #expect(summary == nil, "An empty store has no session to summarize")
        #expect(alarm == nil)
    }
}
