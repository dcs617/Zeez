import Testing
import Foundation
import CoreData
@testable import Zeez

/// Coverage reporting (`PARKED_CAPABILITIES.md` §8b): how much of a period, and of a
/// session, was actually recorded. Tier 1 — it reports presence, never meaning — and a
/// missing night or input must be reported as missing rather than silently dropped.
@Suite("Sleep coverage")
struct SleepCoverageTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: - Night coverage

    @Test("A recording begun after midnight belongs to the previous night")
    func afterMidnightBelongsToPreviousNight() {
        let mondayEvening = date(2026, 10, 12, 22)
        let tuesdayEarly = date(2026, 10, 13, 1)
        #expect(NightCoverage.nightKey(for: mondayEvening, calendar: Self.calendar)
                == NightCoverage.nightKey(for: tuesdayEarly, calendar: Self.calendar))

        let coverage = NightCoverage.calculate(
            sessions: [.init(startTime: mondayEvening, hasEstimate: false),
                       .init(startTime: tuesdayEarly, hasEstimate: true)],
            nightCount: 7, now: date(2026, 10, 13, 9), calendar: Self.calendar)
        #expect(coverage.recordedNights == 1, "Two sessions on one night count once")
        #expect(coverage.nightsWithEstimate == 1)
    }

    @Test("An empty period reports zero recorded nights, not an absent denominator")
    func emptyPeriodReportsNoNights() {
        let coverage = NightCoverage.calculate(sessions: [], nightCount: 7,
                                               now: date(2026, 10, 13, 9), calendar: Self.calendar)
        #expect(coverage == NightCoverage(nightCount: 7, recordedNights: 0, nightsWithEstimate: 0))
        #expect(coverage.summary == "Recorded on 0 of the last 7 nights")
        #expect(coverage.estimateSummary == "No experimental Zeez estimates in this period")
    }

    @Test("Nights with a recording but no estimate are recorded, not estimated")
    func estimatesAreCountedSeparately() {
        let now = date(2026, 10, 13, 9)
        let sessions = (0..<5).map { offset in
            NightCoverage.Session(startTime: date(2026, 10, 12 - offset, 23), hasEstimate: offset < 2)
        }
        let coverage = NightCoverage.calculate(sessions: sessions, nightCount: 7, now: now, calendar: Self.calendar)
        #expect(coverage.recordedNights == 5)
        #expect(coverage.nightsWithEstimate == 2)
        #expect(coverage.summary == "Recorded on 5 of the last 7 nights")
    }

    /// The Trends fetch window is `now - 7 days ... now`. Whatever the time of day, every session
    /// that window returns must map onto at most seven nights, or the screen would claim
    /// "8 of the last 7".
    @Test("A week's fetch window never yields more nights than the period has")
    func weekWindowNeverOvercounts() {
        for hour in 0..<24 {
            let now = date(2026, 10, 13, hour, 30)
            let start = Self.calendar.date(byAdding: .day, value: -7, to: now)!
            var sessions: [NightCoverage.Session] = []
            var cursor = start.addingTimeInterval(60)
            while cursor <= now {
                sessions.append(.init(startTime: cursor, hasEstimate: true))
                cursor = cursor.addingTimeInterval(3600)
            }
            let nights = NightCoverage.nightCount(from: start, to: now, calendar: Self.calendar)
            let coverage = NightCoverage.calculate(sessions: sessions, nightCount: nights,
                                                   now: now, calendar: Self.calendar)
            #expect(nights == 7)
            // Six is correct shortly after noon, when tonight has no session yet.
            #expect((6...7).contains(coverage.recordedNights),
                    "now at \(hour):30 counted \(coverage.recordedNights) nights")
        }
    }

    @Test("A period spanning a daylight-saving change still has one night per day")
    func daylightSavingDoesNotShiftNights() {
        // US clocks spring forward on 2026-03-08.
        let now = date(2026, 3, 11, 9)
        let sessions = (0..<7).map { offset in
            NightCoverage.Session(startTime: date(2026, 3, 10 - offset, 23), hasEstimate: false)
        }
        let start = Self.calendar.date(byAdding: .day, value: -7, to: now)!
        let coverage = NightCoverage.calculate(
            sessions: sessions,
            nightCount: NightCoverage.nightCount(from: start, to: now, calendar: Self.calendar),
            now: now, calendar: Self.calendar)
        #expect(coverage.recordedNights == 7)
        #expect(coverage.nightCount == 7)
    }

    @Test("A month's period counts that month's nights")
    func monthPeriodCountsCalendarDays() {
        let now = date(2026, 10, 13, 9)
        let start = Self.calendar.date(byAdding: .month, value: -1, to: now)!
        #expect(NightCoverage.nightCount(from: start, to: now, calendar: Self.calendar) == 30)
    }

    // MARK: - Session input coverage

    private func metrics(appleHealth: Bool, stages: [(String, TimeInterval)]) -> DerivedSleepMetrics {
        let start = date(2026, 10, 12, 23)
        var cursor = start
        let intervals = stages.map { type, duration -> SleepMetricStageInterval in
            defer { cursor = cursor.addingTimeInterval(duration) }
            return SleepMetricStageInterval(type: type, startTime: cursor,
                                            endTime: cursor.addingTimeInterval(duration), duration: duration)
        }
        return DerivedSleepMetrics.calculate(startTime: start, endTime: start.addingTimeInterval(8 * 3600),
                                             isAppleHealthSource: appleHealth, stages: intervals)
    }

    @Test("Every input is listed, and missing ones say so")
    func missingInputsAreListedNotOmitted() {
        let coverage = SessionInputCoverage.calculate(
            isAppleHealthSource: false,
            counts: .init(),
            metrics: metrics(appleHealth: false, stages: []))
        #expect(coverage.entries.map(\.input) == SessionInputCoverage.Input.allCases)
        #expect(coverage.recordedCount == 0)
        #expect(coverage.summary == "0 of 7 inputs recorded")
    }

    @Test("A Zeez recording reports its sensors and says time asleep is Apple Health only")
    func zeezRecordingCoverage() {
        let coverage = SessionInputCoverage.calculate(
            isAppleHealthSource: false,
            counts: .init(stages: 12, heartRate: 480, movement: 1, environmental: 96),
            metrics: metrics(appleHealth: false, stages: [("LIGHT", 3600)]))
        let status = Dictionary(uniqueKeysWithValues: coverage.entries.map { ($0.input, $0.status) })

        #expect(status[.sleepStages] == .recorded("Experimental Zeez estimate"))
        #expect(status[.timeAsleep] == .missing("Only available for Apple Health imports"))
        #expect(status[.inBed] == .missing("Not reported"))
        #expect(status[.heartRate] == .recorded("480 samples"))
        #expect(status[.respiratoryRate] == .missing("Not recorded"))
        #expect(status[.movement] == .recorded("1 sample"))
        #expect(status[.roomEnvironment] == .recorded("96 readings"))
        #expect(coverage.recordedCount == 4)
    }

    @Test("An Apple Health import reports stages, time asleep and in-bed with provenance")
    func appleHealthImportCoverage() {
        let coverage = SessionInputCoverage.calculate(
            isAppleHealthSource: true,
            counts: .init(stages: 2, heartRate: 0, respiratory: 30),
            metrics: metrics(appleHealth: true, stages: [("inBed", 8.0 * 3600), ("deep", 3600), ("rem", 3600)]))
        let status = Dictionary(uniqueKeysWithValues: coverage.entries.map { ($0.input, $0.status) })

        #expect(status[.sleepStages] == .recorded("Reported by Apple Health"))
        #expect(status[.timeAsleep] == .recorded("Reported by Apple Health"))
        #expect(status[.inBed] == .recorded("Reported by Apple Health"))
        #expect(status[.heartRate] == .missing("Not recorded"))
        #expect(status[.respiratoryRate] == .recorded("30 samples"))
    }

    @Test("In-bed rows alone are context, not recorded sleep stages")
    func inBedRowsAreNotStages() {
        let context = PersistenceController(inMemory: true).container.viewContext
        // Assert outside the closure: off the main actor, an issue recorded inside a
        // viewContext closure reaches no test.
        let status = context.performAndWait {
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = date(2026, 10, 12, 23)
            session.endTime = date(2026, 10, 13, 7)
            session.deviceIdentifier = AppConstants.DataProvenance.healthKitMarker

            let inBed = SleepStage(context: context)
            inBed.id = UUID()
            inBed.stageType = "inBed"
            inBed.startTime = session.startTime
            inBed.endTime = session.endTime
            inBed.duration = 8 * 3600
            inBed.session = session

            return session.inputCoverage.entries.first { $0.input == .sleepStages }?.status
        }

        #expect(status == .missing("Not available"))
    }
}
