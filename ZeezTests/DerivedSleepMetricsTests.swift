import Foundation
import Testing
@testable import Zeez

struct DerivedSleepMetricsTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func interval(_ type: String, from hour: Double, to endHour: Double) -> SleepMetricStageInterval {
        let stageStart = start.addingTimeInterval(hour * 3600)
        let stageEnd = start.addingTimeInterval(endHour * 3600)
        return SleepMetricStageInterval(
            type: type,
            startTime: stageStart,
            endTime: stageEnd,
            duration: stageEnd.timeIntervalSince(stageStart)
        )
    }

    private func importedMetrics(_ stages: [SleepMetricStageInterval]) -> DerivedSleepMetrics {
        DerivedSleepMetrics.calculate(
            startTime: start,
            endTime: start.addingTimeInterval(8 * 3600),
            isAppleHealthSource: true,
            stages: stages
        )
    }

    @Test("Apple Health stage metrics retain derived Apple Health provenance")
    func importedStageProvenanceIsRetained() throws {
        let metrics = importedMetrics([
            interval("light", from: 0, to: 4),
            interval("deep", from: 4, to: 6),
            interval("rem", from: 6, to: 8)
        ])

        let composition = try #require(metrics.asleepStageComposition.value)
        #expect(metrics.asleepStageComposition.provenance == .derivedFromAppleHealth)
        #expect(metrics.qualifiedAsleepDuration.provenance == .derivedFromAppleHealth)
        #expect(try #require(composition[.lightSleep]) == 4 * 3600.0)
    }

    @Test("In-bed context is excluded from asleep composition but supplies efficiency denominator")
    func inBedIsOnlyContext() throws {
        let metrics = importedMetrics([
            interval("inBed", from: 0, to: 8),
            interval("light", from: 0.5, to: 4),
            interval("deep", from: 4, to: 6),
            interval("rem", from: 6, to: 7.5)
        ])

        let composition = try #require(metrics.asleepStageComposition.value)
        #expect(composition.values.reduce(0, +) == 7 * 3600)
        #expect(try #require(metrics.reportedInBedDuration.value) == 8 * 3600.0)
        #expect(abs((try #require(metrics.sleepEfficiency.value)) - 87.5) < 0.01)
    }

    @Test("Unspecified asleep remains an explicit asleep stage")
    func unspecifiedAsleepIsRetained() throws {
        let metrics = importedMetrics([
            interval("asleepUnspecified", from: 0, to: 3),
            interval("rem", from: 3, to: 4)
        ])

        let composition = try #require(metrics.asleepStageComposition.value)
        #expect(try #require(composition[.asleepUnspecified]) == 3 * 3600.0)
        #expect(composition[.lightSleep] == nil)
        #expect(try #require(metrics.qualifiedAsleepDuration.value) == 4 * 3600.0)
    }

    @Test("Missing qualified asleep evidence leaves asleep-dependent metrics unavailable")
    func missingAsleepDoesNotUseRecordedInterval() throws {
        let metrics = importedMetrics([
            interval("inBed", from: 0, to: 8),
            interval("awake", from: 1, to: 1.25)
        ])

        #expect(try #require(metrics.recordedSessionInterval.value) == 8 * 3600.0)
        #expect(metrics.qualifiedAsleepDuration.value == nil)
        #expect(metrics.goalComparisonDuration.value == nil)
        #expect(metrics.sleepEfficiency.value == nil)
    }

    @Test("Awake and efficiency are unavailable without reported required inputs")
    func awakeAndEfficiencyRequireEvidence() {
        let metrics = importedMetrics([
            interval("light", from: 0, to: 7)
        ])

        #expect(metrics.recordedAwakeDuration.value == nil)
        #expect(metrics.sleepEfficiency.value == nil)
        #expect(metrics.reportedInBedDuration.value == nil)
    }

    @Test("Goal shortfall compares selected goal with qualified Apple Health asleep duration")
    func goalShortfallUsesQualifiedDuration() throws {
        let metrics = importedMetrics([
            interval("inBed", from: 0, to: 8),
            interval("light", from: 0, to: 5),
            interval("asleepUnspecified", from: 5, to: 7)
        ])

        let shortfall = try #require(metrics.goalShortfall(for: 8 * 3600).value)
        #expect(shortfall == 3600)
        #expect(metrics.goalShortfall(for: 8 * 3600).provenance == .derivedFromAppleHealth)
    }

    @Test("Conflicting source stage overlaps do not create a stage composition result")
    func conflictingStageCoverageIsUnavailable() throws {
        let metrics = importedMetrics([
            interval("light", from: 0, to: 4),
            interval("deep", from: 3, to: 5)
        ])

        #expect(metrics.asleepStageComposition.value == nil)
        #expect(try #require(metrics.qualifiedAsleepDuration.value) == 5 * 3600.0)
    }

    @Test("Recorded Zeez sessions can compare their interval to a goal without claiming qualified asleep")
    func locallyRecordedGoalComparisonUsesRecordedInterval() throws {
        let metrics = DerivedSleepMetrics.calculate(
            startTime: start,
            endTime: start.addingTimeInterval(6.5 * 3600),
            isAppleHealthSource: false,
            stages: []
        )

        #expect(metrics.qualifiedAsleepDuration.value == nil)
        #expect(metrics.goalComparisonDuration.provenance == .recordedSession)
        #expect(try #require(metrics.goalShortfall(for: 8 * 3600).value) == 1.5 * 3600)
    }
}
