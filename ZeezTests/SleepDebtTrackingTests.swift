import CoreData
import Foundation
import Testing
@testable import Zeez

struct SleepDebtTrackingTests {
    // viewContext is main-queue-confined and Swift Testing runs tests off the
    // main thread — all Core Data work below runs inside performAndWait (2.4).
    private func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    private func date(_ day: Int, hour: Int = 0) -> Date {
        Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 5, day: day, hour: hour)
        )!
    }

    private func addPreferences(goalHours: Double = 8, in context: NSManagedObjectContext) {
        let preferences = UserPreferences(context: context)
        preferences.id = UUID()
        preferences.sleepGoalEnabled = true
        preferences.targetSleepDuration = goalHours * 3600
    }

    private func addSession(
        start: Date,
        hours: Double,
        source: String,
        in context: NSManagedObjectContext
    ) -> SleepSession {
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = start
        session.endTime = start.addingTimeInterval(hours * 3600)
        session.deviceIdentifier = source
        session.isActive = false
        return session
    }

    private func addStage(
        _ type: String,
        hours: Double,
        to session: SleepSession,
        in context: NSManagedObjectContext
    ) {
        let stage = SleepStage(context: context)
        stage.id = UUID()
        stage.stageType = type
        stage.duration = hours * 3600
        stage.session = session
    }

    @Test("Goal shortfall uses reported asleep stages and excludes in-bed time")
    func healthKitShortfallUsesReportedSleepOnly() throws {
        let context = makeContext()
        try context.performAndWait {
            addPreferences(in: context)
            let session = addSession(
                start: date(25, hour: 22),
                hours: 9,
                source: "HealthKit Import",
                in: context
            )
            addStage("inBed", hours: 9, to: session, in: context)
            addStage("asleepUnspecified", hours: 7, to: session, in: context)
            addStage("awake", hours: 1, to: session, in: context)
            try context.save()

            let summary = try #require(
                SleepDebtCalculator.shared.summary(forDays: 7, endingAt: date(26), context: context)
            )

            #expect(summary.coveredDayCount == 1)
            #expect(summary.days[0].comparedDuration == 7 * 3600)
            #expect(summary.totalShortfall == 1 * 3600)
            #expect(!summary.usesEstimatedDurations)
        }
    }

    @Test("Goal shortfall excludes missing days and identifies recorded Zeez durations as estimated")
    func missingDaysDoNotCreateDebt() throws {
        let context = makeContext()
        try context.performAndWait {
            addPreferences(in: context)
            _ = addSession(
                start: date(24, hour: 22),
                hours: 6.5,
                source: "Manual Session",
                in: context
            )
            try context.save()

            let summary = try #require(
                SleepDebtCalculator.shared.summary(forDays: 7, endingAt: date(26), context: context)
            )

            #expect(summary.coveredDayCount == 1)
            #expect(summary.totalShortfall == 1.5 * 3600)
            #expect(summary.usesEstimatedDurations)
        }
    }

    @Test("HealthKit in-bed context without reported asleep time is not treated as sleep")
    func inBedOnlyImportHasNoUsableDuration() throws {
        let context = makeContext()
        try context.performAndWait {
            addPreferences(in: context)
            let session = addSession(
                start: date(25, hour: 22),
                hours: 8,
                source: "HealthKit Import",
                in: context
            )
            addStage("inBed", hours: 8, to: session, in: context)
            try context.save()

            let summary = try #require(
                SleepDebtCalculator.shared.summary(forDays: 7, endingAt: date(26), context: context)
            )

            #expect(summary.coveredDayCount == 0)
            #expect(summary.totalShortfall == 0)
        }
    }

    @Test("Sleep goal duration correctly spans an overnight schedule")
    func overnightGoalDurationWrapsAtMidnight() {
        let bedtime = date(25, hour: 23)
        let wakeTime = date(25, hour: 7)

        #expect(SleepGoalPolicy.duration(from: bedtime, to: wakeTime) == 8 * 3600)
    }

    @Test("Daily metrics keep duration and goal shortfall in seconds")
    func dailyMetricsUseConsistentTimeUnits() async throws {
        let context = makeContext()
        let session = try context.performAndWait {
            addPreferences(goalHours: 8, in: context)
            let session = addSession(
                start: date(25, hour: 22),
                hours: 6,
                source: "Manual Session",
                in: context
            )
            try context.save()
            return session
        }

        try await SleepMetricsCalculator().updateDailyMetrics(for: session, in: context)

        try context.performAndWait {
            let metrics = try #require(try context.fetch(DailyMetrics.fetchRequest()).first)
            #expect(metrics.totalSleepTime == 6 * 3600)
            #expect(metrics.sleepDebt == 2 * 3600)
        }
    }
}
