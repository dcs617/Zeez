import Testing
import Foundation
import CoreData
@testable import Zeez

/// Deterministic test vectors for `ZEEZ_SCORE_SPECIFICATION.md` (ZeezScore-3.0).
/// The claims contract requires these before a Tier-3 score may be presented at all.
///
/// Two properties matter most and are asserted directly: a missing input makes its
/// component unavailable rather than a neutral default, and stage shares are weighted
/// by duration rather than by how many stage records exist.
@Suite("Sleep quality calculator")
struct SleepQualityCalculatorTests {

    // MARK: - Fixtures

    /// Fixtures are anchored to a fixed instant rather than `Date()`.
    ///
    /// Sessions used to be built as `start = Date() - 8h` and `end = Date()`, two separate
    /// clock reads. The recording window was therefore `28800 + δ` seconds, where δ is
    /// however long elapsed between them. `sleepOpportunityResult` divides asleep time by
    /// that window, so a vector expecting a ratio of exactly 0.5 got 0.49999999998 whenever
    /// the two reads straddled a microsecond boundary — a flake that only appeared under
    /// parallel load. The specification this suite exists to pin requires *deterministic*
    /// test vectors, so the clock has no business here.
    private static let sessionEnd = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func start(hoursBefore hours: Double) -> Date {
        sessionEnd.addingTimeInterval(-hours * 3600)
    }

    private func makeSession(in context: NSManagedObjectContext,
                             start: Date?, end: Date?) -> SleepSession {
        var session: SleepSession!
        context.performAndWait {
            session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = start
            session.endTime = end
            session.isActive = false
        }
        return session
    }

    @discardableResult
    private func addStage(_ type: String, to session: SleepSession,
                          in context: NSManagedObjectContext,
                          start: Date, duration: TimeInterval) -> SleepStage {
        var stage: SleepStage!
        context.performAndWait {
            stage = SleepStage(context: context)
            stage.id = UUID()
            stage.stageType = type
            stage.startTime = start
            stage.endTime = start.addingTimeInterval(duration)
            stage.duration = duration
            stage.session = session
        }
        return stage
    }

    private func addMovement(to session: SleepSession, in context: NSManagedObjectContext) {
        context.performAndWait {
            let movement = MovementData(context: context)
            movement.id = UUID()
            movement.timestamp = session.startTime
            movement.session = session
        }
    }

    private func addHeartRate(to session: SleepSession, in context: NSManagedObjectContext) {
        context.performAndWait {
            let sample = HeartRateData(context: context)
            sample.id = UUID()
            sample.timestamp = session.startTime
            sample.value = 60
            sample.session = session
        }
    }

    private func metrics(for session: SleepSession, context: NSManagedObjectContext) -> QualityMetrics? {
        var result: QualityMetrics?
        context.performAndWait {
            result = SleepQualityCalculator(session: session, context: context).calculateMetrics()
        }
        return result
    }

    /// 8 h, 20 equal stages: deep 4 (20%), light 11 (55%), rem 5 (25%) — every share
    /// inside its optimal band; onset at t=0; zero wake episodes; opportunity 1.0.
    private func makePerfectSession(in context: NSManagedObjectContext) -> SleepSession {
        let start = Self.start(hoursBefore: 8)
        let session = makeSession(in: context, start: start, end: Self.sessionEnd)
        var cursor = start
        let stageLength = 8.0 * 3600 / 20
        let plan = Array(repeating: "DEEP", count: 4)
                 + Array(repeating: "LIGHT", count: 11)
                 + Array(repeating: "REM", count: 5)
        for type in plan {
            addStage(type, to: session, in: context, start: cursor, duration: stageLength)
            cursor = cursor.addingTimeInterval(stageLength)
        }
        return session
    }

    // MARK: - Weighting

    @Test("Every component at 100 composites to exactly 100, so the weights sum to 1")
    func perfectSessionScoresExactly100() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let session = makePerfectSession(in: context)

        let m = try #require(metrics(for: session, context: context))
        #expect(m.durationScore == 100)
        #expect(m.sleepOpportunityScore == 100)
        #expect(m.stageDistributionScore == 100)
        #expect(m.fragmentationScore == 100)
        #expect(m.latencyScore == 100)
        #expect(abs(m.overallScore - 100) < 0.0001, "Weights must sum to 1.0")
        #expect(abs(m.inputCoverage - 100) < 0.0001, "Every component was available")
        #expect(m.version == ZeezScore.version)
    }

    @Test("Component weights sum to exactly 1.0")
    func componentWeightsSumToOne() {
        let total = ZeezScoreComponent.allCases.reduce(0.0) { $0 + $1.weight }
        #expect(abs(total - 1.0) < 0.0001)
    }

    // MARK: - Missing-input policy (claims rule 4)

    @Test("A session without stages gets no estimate rather than neutral defaults")
    func sessionWithoutStagesHasNoEstimate() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let session = makeSession(in: context,
                                  start: Self.start(hoursBefore: 8),
                                  end: Self.sessionEnd)

        // Pre-3.0 this scored 100/85/75/85/85 → a composite near 86.
        #expect(metrics(for: session, context: context) == nil)
    }

    @Test("A session without valid times gets no estimate")
    func sessionWithoutTimesHasNoEstimate() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let session = makeSession(in: context, start: nil, end: nil)

        #expect(metrics(for: session, context: context) == nil)
    }

    @Test("A session whose stages are all awake has no asleep evidence and no estimate")
    func sessionWithOnlyAwakeStagesHasNoEstimate() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let start = Self.start(hoursBefore: 8)
        let session = makeSession(in: context, start: start, end: Self.sessionEnd)
        addStage("AWAKE", to: session, in: context, start: start, duration: 8 * 3600)

        #expect(metrics(for: session, context: context) == nil)
    }

    @Test("Required components gate the estimate no matter how good the rest are")
    func requiredComponentsAreDurationAndStageDistribution() {
        let required = Set(ZeezScoreComponent.allCases.filter(\.isRequired))
        #expect(required == [.duration, .stageDistribution])
    }

    @Test("An unavailable optional component renormalizes rather than scoring as average")
    func unavailableOptionalComponentRenormalizes() throws {
        // Deep 20% / Light 55% / REM 25% of asleep time (distribution = 100), but the
        // asleep intervals cover only half the recording window, so opportunity scores
        // max(20, 50) = 50. Duration 8 h = 100. No awake stages: fragmentation = 100.
        // Onset at t=0: latency = 100.
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let start = Self.start(hoursBefore: 8)
        let session = makeSession(in: context, start: start, end: Self.sessionEnd)

        var cursor = start
        let stageLength = 4.0 * 3600 / 20  // asleep covers 4 h of the 8 h window
        let plan = Array(repeating: "DEEP", count: 4)
                 + Array(repeating: "LIGHT", count: 11)
                 + Array(repeating: "REM", count: 5)
        for type in plan {
            addStage(type, to: session, in: context, start: cursor, duration: stageLength)
            cursor = cursor.addingTimeInterval(stageLength)
        }

        let m = try #require(metrics(for: session, context: context))
        #expect(m.sleepOpportunityScore == 50)
        // Component score × weight, summed. One long literal sum is more than Xcode 16.4's type
        // checker will solve, even annotated.
        let weighted: [Double] = [100 * 0.25, 50 * 0.30, 100 * 0.25, 100 * 0.15, 100 * 0.05]
        let expected = weighted.reduce(0, +)
        #expect(abs(m.overallScore - expected) < 0.0001)
    }

    @Test("Coverage below the floor produces no estimate")
    func coverageFloorIsEnforced() {
        // duration + stageDistribution alone are 50% coverage, under the 60% floor —
        // so the floor really does bite even when both required components are present.
        #expect(ZeezScore.minimumCoverage > (ZeezScoreComponent.duration.weight
                                             + ZeezScoreComponent.stageDistribution.weight) * 100)
    }

    // MARK: - Duration bands

    @Test("Duration bands match the specification table")
    func durationBandsMatchSpecification() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let cases: [(hours: Double, score: Double)] = [
            (8, 100), (6.5, 85), (9.5, 85), (5.5, 70), (4.5, 50), (3, 25), (13, 25)
        ]
        for c in cases {
            let start = Self.start(hoursBefore: c.hours)
            let session = makeSession(in: context, start: start, end: Self.sessionEnd)
            // Stages keep the estimate available so durationScore is observable.
            addStage("LIGHT", to: session, in: context, start: start, duration: c.hours * 3600)

            let m = try #require(metrics(for: session, context: context))
            #expect(m.durationScore == c.score, "\(c.hours) h should score \(c.score)")
        }
    }

    // MARK: - Fragmentation

    @Test("Four mid-night wake episodes score 70")
    func fourWakeEpisodesScore70() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let start = Self.start(hoursBefore: 8)
        let session = makeSession(in: context, start: start, end: Self.sessionEnd)

        // sleep → (awake → sleep) ×4 = 4 mid-night wake episodes
        var cursor = start
        let hour: TimeInterval = 3600
        var plan = ["LIGHT"]
        for _ in 0..<4 { plan += ["AWAKE", "LIGHT"] }
        for type in plan {
            addStage(type, to: session, in: context, start: cursor, duration: hour / 2)
            cursor = cursor.addingTimeInterval(hour / 2)
        }

        let m = try #require(metrics(for: session, context: context))
        #expect(m.fragmentationScore == 70)
    }

    // MARK: - Duration-weighted stage distribution (the B8 fix)

    @Test("Stage distribution weights durations, not stage record counts")
    func stageDistributionWeightsDurationsNotCounts() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let start = Self.start(hoursBefore: 8)

        // Light and REM records are fixed at 24 min each. Only the length of the four
        // DEEP records varies, so the stage RECORD COUNTS are identical in both sessions.
        func build(deepDuration: TimeInterval) -> SleepSession {
            let session = makeSession(in: context, start: start, end: Self.sessionEnd)
            var cursor = start
            let plan = Array(repeating: "DEEP", count: 4)
                     + Array(repeating: "LIGHT", count: 11)
                     + Array(repeating: "REM", count: 5)
            for type in plan {
                let duration = type == "DEEP" ? deepDuration : 1440
                addStage(type, to: session, in: context, start: cursor, duration: duration)
                cursor = cursor.addingTimeInterval(duration)
            }
            return session
        }

        // 24-min deep records → deep is 20% of asleep time, inside the optimal band.
        let longDeep = try #require(metrics(for: build(deepDuration: 1440), context: context))
        // 1-min deep records → deep is ~1% of asleep time, far outside acceptable.
        let shortDeep = try #require(metrics(for: build(deepDuration: 60), context: context))

        #expect(longDeep.stageDistributionScore == 100)
        #expect(shortDeep.stageDistributionScore == 40)
        #expect(try #require(shortDeep.stageDistributionScore) < #require(longDeep.stageDistributionScore),
                "Counting stage records made these identical; 3.0 weights by duration")
    }

    @Test("Unspecified asleep stays in the denominator and is never redistributed")
    func unspecifiedAsleepDilutesRatherThanBeingRedistributed() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let start = Self.start(hoursBefore: 8)

        // Half the asleep time is unspecified. If it were redistributed into the typed
        // stages, the typed shares would still look optimal and score 100.
        let session = makeSession(in: context, start: start, end: Self.sessionEnd)
        var cursor = start
        for (type, duration) in [("DEEP", 0.8 * 3600), ("LIGHT", 2.2 * 3600),
                                 ("REM", 1.0 * 3600), ("ASLEEP_UNSPECIFIED", 4.0 * 3600)] {
            addStage(type, to: session, in: context, start: cursor, duration: duration)
            cursor = cursor.addingTimeInterval(duration)
        }

        let m = try #require(metrics(for: session, context: context))
        let distribution = try #require(m.stageDistributionScore)
        #expect(distribution < 100, "Unspecified asleep must dilute the typed stage shares")
    }

    // MARK: - Derived confidence (replaces the constant 85.0)

    @Test("Confidence rises with sensor breadth and is never the old constant")
    func confidenceIsDerivedFromCoverageAndSensorBreadth() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let noSensors = try #require(metrics(for: makePerfectSession(in: context), context: context))

        let oneSensorSession = makePerfectSession(in: context)
        addMovement(to: oneSensorSession, in: context)
        let oneSensor = try #require(metrics(for: oneSensorSession, context: context))

        let bothSensorsSession = makePerfectSession(in: context)
        addMovement(to: bothSensorsSession, in: context)
        addHeartRate(to: bothSensorsSession, in: context)
        let bothSensors = try #require(metrics(for: bothSensorsSession, context: context))

        // Full coverage in all three; only sensor breadth differs.
        #expect(abs(noSensors.confidence - 70) < 0.0001)
        #expect(abs(oneSensor.confidence - 85) < 0.0001)
        #expect(abs(bothSensors.confidence - 100) < 0.0001)
        #expect(noSensors.confidence < oneSensor.confidence)
        #expect(oneSensor.confidence < bothSensors.confidence)
    }

    @Test("Partial coverage lowers confidence below full coverage with the same sensors")
    func partialCoverageLowersConfidence() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let full = makePerfectSession(in: context)
        addMovement(to: full, in: context)
        addHeartRate(to: full, in: context)
        let fullMetrics = try #require(metrics(for: full, context: context))

        #expect(fullMetrics.inputCoverage == 100)
        #expect(fullMetrics.confidence == fullMetrics.inputCoverage * 1.0)
    }
}
