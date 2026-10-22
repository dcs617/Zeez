import Testing
@testable import Zeez

/// Second-audit B10: the importer used to fire the heart-rate and respiratory sub-imports
/// and forget them, so "imported N sessions" could be reported while both silently failed.
@Suite("Import result reporting (B10)")
struct ImportResultReportingTests {

    private func result(sessions: Int,
                        heartRate: RelatedDataOutcome,
                        respiratory: RelatedDataOutcome) -> HealthKitImportResult {
        HealthKitImportResult(sessionCount: sessions, heartRate: heartRate, respiratory: respiratory)
    }

    @Test("A failed sub-import marks the result as a partial failure")
    func failedSubImportIsAPartialFailure() {
        let r = result(sessions: 30,
                       heartRate: .failed("network"),
                       respiratory: .imported(readingCount: 12))
        #expect(r.hasPartialFailure)
    }

    @Test("Unavailable data types are not failures")
    func unavailableIsNotAFailure() {
        let r = result(sessions: 30, heartRate: .unavailable, respiratory: .unavailable)
        #expect(!r.hasPartialFailure)
    }

    @Test("Zero readings is not a failure — the source simply had none")
    func zeroReadingsIsNotAFailure() {
        let r = result(sessions: 30,
                       heartRate: .imported(readingCount: 0),
                       respiratory: .imported(readingCount: 0))
        #expect(!r.hasPartialFailure)
    }

    // MARK: - User-facing message

    @Test("A fully successful import names both data types and their reading counts")
    func successMessageNamesEachDataType() {
        let message = SimpleDataImportView.statusMessage(
            for: result(sessions: 30,
                        heartRate: .imported(readingCount: 480),
                        respiratory: .imported(readingCount: 12))
        )
        #expect(message.contains("30 sleep sessions"))
        #expect(message.contains("Heart rate: 480 readings"))
        #expect(message.contains("Respiratory rate: 12 readings"))
        #expect(!message.contains("⚠️"))
    }

    @Test("A partial failure is surfaced instead of being reported as success")
    func partialFailureIsSurfaced() {
        let message = SimpleDataImportView.statusMessage(
            for: result(sessions: 30,
                        heartRate: .failed("HealthKit query failed"),
                        respiratory: .imported(readingCount: 12))
        )
        #expect(message.contains("⚠️"))
        #expect(message.contains("Heart rate: could not be imported"))
        #expect(message.contains("retry"), "The user needs to know the sessions were kept and how to fix it")
    }

    @Test("An unavailable type says so rather than implying data was missing")
    func unavailableTypeIsExplained() {
        let message = SimpleDataImportView.statusMessage(
            for: result(sessions: 5,
                        heartRate: .unavailable,
                        respiratory: .imported(readingCount: 3))
        )
        #expect(message.contains("Heart rate: not available on this device"))
        #expect(!message.contains("⚠️"))
    }

    @Test("Zero readings reads as none recorded, not as an error")
    func zeroReadingsReadsAsNoneRecorded() {
        let message = SimpleDataImportView.statusMessage(
            for: result(sessions: 5,
                        heartRate: .imported(readingCount: 0),
                        respiratory: .imported(readingCount: 0))
        )
        #expect(message.contains("Heart rate: none recorded"))
        #expect(!message.contains("⚠️"))
    }

    @Test("No sessions produces the guidance message, not a per-type breakdown")
    func noSessionsProducesGuidance() {
        let message = SimpleDataImportView.statusMessage(
            for: result(sessions: 0,
                        heartRate: .imported(readingCount: 0),
                        respiratory: .imported(readingCount: 0))
        )
        #expect(message.contains("No sleep data found"))
        #expect(!message.contains("Heart rate"))
    }

    @Test("A single session is described in the singular")
    func singleSessionIsSingular() {
        let message = SimpleDataImportView.statusMessage(
            for: result(sessions: 1,
                        heartRate: .imported(readingCount: 1),
                        respiratory: .unavailable)
        )
        #expect(message.contains("1 sleep session from"))
    }

    // MARK: - Re-import (§8a)

    @Test("A re-import that changed nothing says the data is up to date, not that there is none")
    func unchangedReimportIsUpToDate() {
        var r = result(sessions: 0, heartRate: .imported(readingCount: 0), respiratory: .imported(readingCount: 0))
        r.fetchedNightCount = 12
        let message = SimpleDataImportView.statusMessage(for: r)
        #expect(message.contains("Already up to date"))
        #expect(!message.contains("No sleep data found"))
        #expect(!message.contains("Heart rate"))
    }

    @Test("Updated sessions are reported, with the readings refreshed for them")
    func updatedSessionsAreReported() {
        var r = result(sessions: 0, heartRate: .imported(readingCount: 90), respiratory: .imported(readingCount: 4))
        r.updatedSessionCount = 2
        r.fetchedNightCount = 12
        let message = SimpleDataImportView.statusMessage(for: r)
        #expect(message.contains("Updated 2 sleep sessions that changed in Apple Health"))
        #expect(message.contains("Heart rate: 90 readings"))
        #expect(!message.contains("Imported 0"))
    }

    @Test("Removed sessions are reported, without a readings breakdown")
    func removedSessionsAreReported() {
        var r = result(sessions: 0, heartRate: .imported(readingCount: 0), respiratory: .imported(readingCount: 0))
        r.removedSessionCount = 1
        let message = SimpleDataImportView.statusMessage(for: r)
        #expect(message.contains("Removed 1 sleep session deleted in Apple Health"))
        #expect(!message.contains("Heart rate"))
        #expect(!message.contains("No sleep data found"))
    }

    @Test("New and updated sessions are reported together")
    func newAndUpdatedAreReportedTogether() {
        var r = result(sessions: 3, heartRate: .imported(readingCount: 200), respiratory: .unavailable)
        r.updatedSessionCount = 1
        let message = SimpleDataImportView.statusMessage(for: r)
        #expect(message.contains("Imported 3 sleep sessions from Apple Health"))
        #expect(message.contains("Updated 1 sleep session that changed"))
    }
}
