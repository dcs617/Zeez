import Testing
import Foundation
import CoreData
@testable import Zeez

/// Unit tests for SleepQualityCalculator (roadmap 2.4 step 4): weight math,
/// missing-data defaults, and the count-based stage-distribution behavior.
@Suite("Sleep quality calculator")
struct SleepQualityCalculatorTests {

    // MARK: - Fixtures

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

    private func metrics(for session: SleepSession, context: NSManagedObjectContext) -> QualityMetrics {
        var result: QualityMetrics!
        context.performAndWait {
            result = SleepQualityCalculator(session: session, context: context).calculateMetrics()
        }
        return result
    }

    // MARK: - Weighting

    @Test func perfectSessionScoresExactly100() throws {
        // If every component is 100, the weighted composite must be exactly
        // 100 — i.e. the documented weights (30/25/25/15/5) sum to 1.
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let start = Date().addingTimeInterval(-8 * 3600)
        let session = makeSession(in: context, start: start, end: Date())

        // 20 sleep stages, no awake: deep 4 (20%), light 11 (55%), rem 5 (25%)
        // — every band inside the optimal range; sleep onset at t=0 (latency
        // 0 min); zero wake episodes; efficiency 1.0. Duration 8 h.
        var cursor = start
        let stageLength = 8.0 * 3600 / 20
        let plan = Array(repeating: "DEEP", count: 4)
                 + Array(repeating: "LIGHT", count: 11)
                 + Array(repeating: "REM", count: 5)
        for type in plan {
            addStage(type, to: session, in: context, start: cursor, duration: stageLength)
            cursor = cursor.addingTimeInterval(stageLength)
        }

        let m = metrics(for: session, context: context)
        #expect(m.durationScore == 100)
        #expect(m.efficiencyScore == 100)
        #expect(m.stageDistributionScore == 100)
        #expect(m.fragmentationScore == 100)
        #expect(m.sleepLatencyScore == 100)
        #expect(abs(m.overallScore - 100) < 0.0001, "Weights must sum to 1.0")
    }

    // MARK: - Missing-data defaults

    @Test func sessionWithoutStagesFallsBackToDocumentedDefaults() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let session = makeSession(in: context,
                                  start: Date().addingTimeInterval(-8 * 3600),
                                  end: Date())

        let m = metrics(for: session, context: context)
        #expect(m.durationScore == 100)          // 8 h is optimal
        #expect(m.efficiencyScore == 85)         // no-stage default
        #expect(m.stageDistributionScore == 75)  // no-stage default
        #expect(m.fragmentationScore == 85)      // no-stage default
        #expect(m.sleepLatencyScore == 85)       // no-stage default
        let expected = 100 * 0.25 + 85 * 0.30 + 75 * 0.25 + 85 * 0.15 + 85 * 0.05
        #expect(abs(m.overallScore - expected) < 0.0001)
    }

    @Test func sessionWithoutTimesScoresZeroDuration() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let session = makeSession(in: context, start: nil, end: nil)

        let m = metrics(for: session, context: context)
        #expect(m.durationScore == 0)
    }

    @Test func durationBandsMatchResearchTable() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let cases: [(hours: Double, score: Double)] = [
            (8, 100), (6.5, 85), (9.5, 85), (5.5, 70), (4.5, 50), (3, 25), (13, 25)
        ]
        for c in cases {
            let session = makeSession(in: context,
                                      start: Date().addingTimeInterval(-c.hours * 3600),
                                      end: Date())
            let m = metrics(for: session, context: context)
            #expect(m.durationScore == c.score, "\(c.hours) h should score \(c.score)")
        }
    }

    // MARK: - Fragmentation

    @Test func fourWakeEpisodesScore70() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let start = Date().addingTimeInterval(-8 * 3600)
        let session = makeSession(in: context, start: start, end: Date())

        // sleep → (awake → sleep) ×4 = 4 mid-night wake episodes
        var cursor = start
        let hour: TimeInterval = 3600
        var plan = ["LIGHT"]
        for _ in 0..<4 { plan += ["AWAKE", "LIGHT"] }
        for type in plan {
            addStage(type, to: session, in: context, start: cursor, duration: hour / 2)
            cursor = cursor.addingTimeInterval(hour / 2)
        }

        let m = metrics(for: session, context: context)
        #expect(m.fragmentationScore == 70)
    }

    // MARK: - Known limitation (tracked in roadmap Phase 3)

    @Test func stageDistributionCountsStagesNotDurations() throws {
        // Documents current behavior: distribution scoring counts stage
        // RECORDS, so two sessions with identical counts but wildly different
        // stage durations score identically. Duration-weighted scoring is a
        // Phase-3 roadmap item — when it lands, this test should be updated
        // to assert the opposite.
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let start = Date().addingTimeInterval(-8 * 3600)

        func build(deepDuration: TimeInterval) -> SleepSession {
            let session = makeSession(in: context, start: start, end: Date())
            var cursor = start
            let plan = Array(repeating: "DEEP", count: 4)
                     + Array(repeating: "LIGHT", count: 11)
                     + Array(repeating: "REM", count: 5)
            for type in plan {
                let duration = type == "DEEP" ? deepDuration : 1200
                addStage(type, to: session, in: context, start: cursor, duration: duration)
                cursor = cursor.addingTimeInterval(duration)
            }
            return session
        }

        let shortDeep = metrics(for: build(deepDuration: 60), context: context)
        let longDeep = metrics(for: build(deepDuration: 2 * 3600), context: context)
        #expect(shortDeep.stageDistributionScore == longDeep.stageDistributionScore,
                "Distribution scoring is count-based today; see Phase 3 for duration weighting")
    }
}
