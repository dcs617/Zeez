import Testing
import CoreData
@testable import Zeez

/// Tests that SleepAnalyzer respects the evidence threshold and is idempotent.
///
/// All tests share an in-memory `PersistenceController` instance, which is passed to the
/// testable `analyzeSleepSession(objectID:container:)` overload so that the analyzer
/// resolves object IDs from the same store as the seeded data.
struct SleepAnalysisIdempotencyTests {

    private func makeController() -> PersistenceController {
        PersistenceController(inMemory: true)
    }

    // NOTE: viewContext is main-queue-confined and Swift Testing runs tests
    // off the main thread — every arrange/save below runs inside
    // `context.performAndWait` (2.4; unguarded access made this suite flaky).

    private func makeSession(in context: NSManagedObjectContext,
                              hours: Double = 7.5) -> SleepSession {
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -(hours * 3600))
        session.endTime = Date()
        session.deviceIdentifier = "Manual Session"
        session.qualityScore = 0
        session.isActive = false
        return session
    }

    private func addMovement(to session: SleepSession, context: NSManagedObjectContext, count: Int = 20) {
        guard let start = session.startTime, let end = session.endTime else { return }
        let interval = end.timeIntervalSince(start) / Double(count)
        for i in 0..<count {
            let movement = MovementData(context: context)
            movement.id = UUID()
            movement.timestamp = start.addingTimeInterval(Double(i) * interval)
            movement.magnitude = 0.5
            movement.activityLevel = 1
            movement.session = session
        }
    }

    // MARK: - Insufficient-Data Gating

    @Test("Session with no movement or heart rate receives sentinel score, not a fabricated stage estimate")
    func noDataSessionReceivesSentinel() async throws {
        let controller = makeController()
        let context = controller.container.viewContext
        let objectID = try context.performAndWait {
            let session = makeSession(in: context)
            try context.save()
            return session.objectID
        }
        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: objectID, container: controller.container)

        let bgContext = controller.container.newBackgroundContext()
        let score = try await bgContext.perform {
            let s = try bgContext.existingObject(with: objectID) as? SleepSession
            return s?.qualityScore ?? -1
        }

        #expect(score == 1.0,
                "No-data session should receive sentinel qualityScore 1.0, not a fabricated estimate")

        let stageCount = try await bgContext.perform {
            let s = try bgContext.existingObject(with: objectID) as? SleepSession
            return s?.sleepStages?.count ?? 0
        }
        #expect(stageCount == 0, "No-data session must not have inferred stage records")
    }

    @Test("No-data session has hasDisplayableScore == false")
    func noDataSessionHasNoDisplayableScore() async throws {
        let controller = makeController()
        let context = controller.container.viewContext
        let objectID = try context.performAndWait {
            let session = makeSession(in: context)
            try context.save()
            return session.objectID
        }
        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: objectID, container: controller.container)

        let bgContext = controller.container.newBackgroundContext()
        let hasScore = try await bgContext.perform {
            let s = try bgContext.existingObject(with: objectID) as? SleepSession
            return s?.hasDisplayableScore ?? true
        }
        #expect(!hasScore, "Session with sentinel score must not be considered displayable")
    }

    // MARK: - HealthKit Stage Preservation

    @Test("HealthKit session with source-reported stages is not analyzed and stages are preserved")
    func healthKitSessionWithStagesIsPreserved() async throws {
        let controller = makeController()
        let context = controller.container.viewContext

        let (objectID, stageCountBefore) = try context.performAndWait {
            let session = makeSession(in: context)
            session.deviceIdentifier = "HealthKit Import"

            // Add source-reported stages as an importer would
            let stage = SleepStage(context: context)
            stage.id = UUID()
            stage.startTime = session.startTime
            stage.endTime = session.endTime
            stage.stageType = "deep"
            stage.duration = 3600
            stage.confidence = 85
            stage.session = session

            try context.save()
            return (session.objectID, session.sleepStages?.count ?? 0)
        }

        // Analyzer should detect HealthKit origin and skip without touching stages
        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: objectID, container: controller.container)

        let bgContext = controller.container.newBackgroundContext()
        let (stageCountAfter, score) = try await bgContext.perform {
            let s = try bgContext.existingObject(with: objectID) as? SleepSession
            return (s?.sleepStages?.count ?? 0, s?.qualityScore ?? -1)
        }

        #expect(stageCountAfter == stageCountBefore,
                "Source-reported HealthKit stages must not be deleted or replaced")
        #expect(score == 0,
                "HealthKit session should retain qualityScore=0 (no Zeez estimate)")
    }

    // MARK: - Idempotency

    @Test("Running analysis twice does not double stage count")
    func analysisIsIdempotentForStages() async throws {
        let controller = makeController()
        let context = controller.container.viewContext
        let objectID = try context.performAndWait {
            let session = makeSession(in: context)
            addMovement(to: session, context: context)
            try context.save()
            return session.objectID
        }

        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: objectID, container: controller.container)

        let bgContext1 = controller.container.newBackgroundContext()
        let stageCountAfterFirst = try await bgContext1.perform {
            let s = try bgContext1.existingObject(with: objectID) as? SleepSession
            return s?.sleepStages?.count ?? 0
        }

        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: objectID, container: controller.container)

        let bgContext2 = controller.container.newBackgroundContext()
        let stageCountAfterSecond = try await bgContext2.perform {
            let s = try bgContext2.existingObject(with: objectID) as? SleepSession
            return s?.sleepStages?.count ?? 0
        }

        #expect(stageCountAfterFirst == stageCountAfterSecond,
                "Re-running analysis should replace, not append, stage records")
    }

    @Test("Running analysis twice does not duplicate SleepQualityScore records")
    func analysisIsIdempotentForQualityScores() async throws {
        let controller = makeController()
        let context = controller.container.viewContext
        let objectID = try context.performAndWait {
            let session = makeSession(in: context)
            addMovement(to: session, context: context)
            try context.save()
            return session.objectID
        }

        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: objectID, container: controller.container)
        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: objectID, container: controller.container)

        let bgContext = controller.container.newBackgroundContext()
        let qualityScoreCount = try await bgContext.perform {
            let s = try bgContext.existingObject(with: objectID) as? SleepSession
            return s?.qualityScores?.count ?? 0
        }

        #expect(qualityScoreCount <= 1,
                "Re-running analysis must not append duplicate SleepQualityScore records")
    }

    // MARK: - Evidence Threshold Boundary

    @Test("Session with only heart rate data runs stage analysis and produces a displayable score")
    func heartRateOnlySessionRunsAnalysis() async throws {
        let controller = makeController()
        let context = controller.container.viewContext
        let objectID = try context.performAndWait {
            let session = makeSession(in: context)

            let start = session.startTime!
            for i in 0..<10 {
                let hr = HeartRateData(context: context)
                hr.id = UUID()
                hr.timestamp = start.addingTimeInterval(Double(i) * 2700)
                hr.value = 60.0
                hr.session = session
            }
            try context.save()
            return session.objectID
        }
        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: objectID, container: controller.container)

        let bgContext = controller.container.newBackgroundContext()
        let (score, hasDisplayable) = try await bgContext.perform {
            let s = try bgContext.existingObject(with: objectID) as? SleepSession
            return (s?.qualityScore ?? 0, s?.hasDisplayableScore ?? false)
        }
        #expect(score > 1.0, "Session with heart rate data should receive a real quality estimate")
        #expect(hasDisplayable, "Session with heart rate data should have a displayable score")
    }
}
