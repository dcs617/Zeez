import Testing
import CoreData
@testable import Zeez

/// Tests for the shared score display policy and provenance labeling.
///
/// These tests exercise `SleepSession.hasDisplayableScore` and
/// `QualityScoreCard.scoreProvenance` logic through the data layer rather than duplicating
/// internal view state. Views are expected to delegate all threshold decisions to
/// `hasDisplayableScore` and the `SleepQualityScore` relationship.
struct SleepScorePresentationTests {

    /// viewContext is main-queue-confined and Swift Testing runs tests off main (2.4):
    /// all Core Data work runs inside performAndWait, and the controller stays retained
    /// for the duration of the body. The body returns plain values and the tests assert
    /// outside it — an issue recorded inside a viewContext closure off the main actor
    /// reaches no test, and the test passes (CLAUDE.md, Testing).
    private func withInMemoryContext<T>(_ body: (NSManagedObjectContext) throws -> T) throws -> T {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        return try context.performAndWait {
            try body(context)
        }
    }

    private func attachZeezEstimate(to session: SleepSession, in context: NSManagedObjectContext) {
        let qualityScore = SleepQualityScore(context: context)
        qualityScore.id = UUID()
        qualityScore.overallScore = session.qualityScore
        qualityScore.calculationVersion = ZeezScore.version
        qualityScore.isPersonalized = false
        qualityScore.session = session
    }

    // MARK: - hasDisplayableScore policy

    @Test("Score of 0 (not yet analyzed) is not displayable")
    func scoreZeroIsNotDisplayable() throws {
        let displayable = try withInMemoryContext { context in
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
            session.endTime = Date()
            session.qualityScore = 0
            try context.save()
            return session.hasDisplayableScore
        }

        #expect(!displayable, "qualityScore == 0 must not be displayable (awaiting analysis or HealthKit source-only)")
    }

    @Test("Score of 1.0 (sentinel for no sensor data) is not displayable")
    func sentinelScoreIsNotDisplayable() throws {
        let displayable = try withInMemoryContext { context in
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
            session.endTime = Date()
            session.qualityScore = 1.0
            try context.save()
            return session.hasDisplayableScore
        }

        #expect(!displayable, "qualityScore == 1.0 (sentinel) must not be displayable")
    }

    @Test("Numeric score without a Zeez estimate record is not displayable")
    func orphanScoreIsNotDisplayable() throws {
        let displayable = try withInMemoryContext { context in
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
            session.endTime = Date()
            session.qualityScore = 72.0
            try context.save()
            return session.hasDisplayableScore
        }

        #expect(!displayable, "A number without persisted Zeez estimate provenance must not be displayed")
    }

    // MARK: - HealthKit import

    @Test("HealthKit-imported session starts at qualityScore 0 with no SleepQualityScore entity")
    func healthKitSessionHasNoQualityScoreEntity() throws {
        let (qualityScores, displayable) = try withInMemoryContext { context in
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
            session.endTime = Date()
            session.deviceIdentifier = "HealthKit Import"
            session.qualityScore = 0
            try context.save()
            return (session.qualityScores?.allObjects as? [SleepQualityScore] ?? [], session.hasDisplayableScore)
        }

        #expect(qualityScores.isEmpty, "HealthKit import must not create a SleepQualityScore entity")
        #expect(!displayable, "HealthKit session with score 0 must not be displayable")
    }

    // MARK: - Mock data

    @Test("Debug mock session has a displayable qualityScore set by the generator")
    func mockSessionHasDisplayableQualityScore() throws {
        // Keep the controller alive for the whole test, and run the generator
        // on the viewContext's own queue — it is main-queue-confined and
        // Swift Testing runs tests off main (2.4).
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let generator = MockDataGenerator(context: context)

        let displayable = try context.performAndWait {
            generator.generateMockData(for: 1)

            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            request.predicate = NSPredicate(format: "deviceIdentifier CONTAINS[c] %@", "Mock Data")
            return try context.fetch(request).map(\.hasDisplayableScore)
        }

        #expect(!displayable.isEmpty)
        for sessionDisplayable in displayable {
            #expect(sessionDisplayable, "Mock sessions should always have a displayable quality score")
        }
    }

    // MARK: - Score-provenance distinctness

    @Test("SleepQualityScore entity distinguishes Zeez-estimated from unavailable score")
    func qualityScoreEntityDistinguishesSource() throws {
        let result = try withInMemoryContext { context in
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
            session.endTime = Date()
            session.deviceIdentifier = "Manual Session"
            session.qualityScore = 72.0

            attachZeezEstimate(to: session, in: context)
            try context.save()

            let entities = session.qualityScores?.allObjects as? [SleepQualityScore] ?? []
            return (entityCount: entities.count,
                    version: entities.first?.calculationVersion,
                    displayable: session.hasDisplayableScore,
                    zeezEstimated: session.hasZeezEstimatedScore)
        }

        #expect(result.entityCount == 1, "One SleepQualityScore entity should be attached after analysis")
        #expect(result.version?.contains("ZeezScore") == true)
        #expect(result.displayable, "Session with a Zeez estimate must be displayable")
        #expect(result.zeezEstimated)
    }

    @Test("Imported stages retain Apple Health provenance while Zeez stages are labeled experimental")
    func stageSourceDescriptionIdentifiesProvenance() throws {
        let (imported, zeez) = try withInMemoryContext { context in
            let imported = SleepSession(context: context)
            imported.deviceIdentifier = "HealthKit Import"

            let zeez = SleepSession(context: context)
            zeez.deviceIdentifier = "Local Tracking"

            return ((reported: imported.hasSourceReportedStages, source: imported.stageSourceDescription),
                    (reported: zeez.hasSourceReportedStages, source: zeez.stageSourceDescription))
        }

        #expect(imported.reported)
        #expect(imported.source == "Reported by Apple Health")
        #expect(!zeez.reported)
        #expect(zeez.source == "Experimental Zeez-estimated stages")
    }

    // MARK: - Trends aggregation

    @Test("Trends fetch excludes sessions with non-displayable scores")
    func trendsFetchExcludesNonDisplayableSessions() throws {
        let displayableScores = try withInMemoryContext { context in
            // Sentinel score — should be excluded
            let sentinelSession = SleepSession(context: context)
            sentinelSession.id = UUID()
            sentinelSession.startTime = Date(timeIntervalSinceNow: -8 * 3600)
            sentinelSession.endTime = Date()
            sentinelSession.qualityScore = 1.0

            // Zero score — should be excluded
            let zeroSession = SleepSession(context: context)
            zeroSession.id = UUID()
            zeroSession.startTime = Date(timeIntervalSinceNow: -16 * 3600)
            zeroSession.endTime = Date(timeIntervalSinceNow: -8 * 3600)
            zeroSession.qualityScore = 0

            // Zeez estimate with persisted provenance — should be included
            let realSession = SleepSession(context: context)
            realSession.id = UUID()
            realSession.startTime = Date(timeIntervalSinceNow: -24 * 3600)
            realSession.endTime = Date(timeIntervalSinceNow: -16 * 3600)
            realSession.qualityScore = 78.0
            attachZeezEstimate(to: realSession, in: context)

            try context.save()

            let allSessions = [sentinelSession, zeroSession, realSession]
            return allSessions.filter { $0.hasDisplayableScore }.map(\.qualityScore)
        }

        #expect(displayableScores.count == 1, "Only sessions with score > 1.0 should be included in trend aggregates")
        #expect(displayableScores.first == 78.0)
    }

    @Test("Watch payload states unavailable score and omits its numeric value")
    func watchPayloadOmitsUnavailableScore() throws {
        let summary = try withInMemoryContext { context in
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
            session.endTime = Date()
            session.qualityScore = 1.0
            try context.save()
            return watchSleepSummary(for: session)
        }

        let payload = try #require(summary).toPayload()
        #expect(payload["qualityAvailable"] as? Bool == false)
        #expect(payload["quality"] == nil)
    }

    @Test("Watch payload sends an available score explicitly")
    func watchPayloadIncludesAvailableScore() throws {
        let summary = try withInMemoryContext { context in
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
            session.endTime = Date()
            session.qualityScore = 84
            attachZeezEstimate(to: session, in: context)
            try context.save()
            return watchSleepSummary(for: session)
        }

        let payload = try #require(summary).toPayload()
        #expect(payload["qualityAvailable"] as? Bool == true)
        #expect(payload["quality"] as? Double == 84)
    }

    @Test("Dashboard quality preview renders unavailable without inventing a metric")
    func dashboardPreviewStatesUnavailableScore() throws {
        let stat = try withInMemoryContext { context in
            let session = SleepSession(context: context)
            session.qualityScore = 0
            return SleepQualityPreviewStats.getRandomStat(from: session)
        }

        #expect(stat?.label == "Score")
        #expect(stat?.value == "Unavailable")
    }

    @Test("Dashboard quality preview identifies available values as experimental Zeez estimates")
    func dashboardPreviewLabelsEstimatedScore() throws {
        let stat = try withInMemoryContext { context in
            let session = SleepSession(context: context)
            session.qualityScore = 84
            attachZeezEstimate(to: session, in: context)
            return SleepQualityPreviewStats.getRandomStat(from: session)
        }

        #expect(stat?.label == "Experimental Zeez Estimate")
        #expect(stat?.value == "84 pts")
    }
}
