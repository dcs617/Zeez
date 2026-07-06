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

    private func makeContext() -> NSManagedObjectContext {
        PersistenceController(inMemory: true).container.viewContext
    }

    private func attachZeezEstimate(to session: SleepSession, in context: NSManagedObjectContext) {
        let qualityScore = SleepQualityScore(context: context)
        qualityScore.id = UUID()
        qualityScore.overallScore = session.qualityScore
        qualityScore.calculationVersion = "SleepAnalyzer-2.0"
        qualityScore.isPersonalized = false
        qualityScore.session = session
    }

    // MARK: - hasDisplayableScore policy

    @Test("Score of 0 (not yet analyzed) is not displayable")
    func scoreZeroIsNotDisplayable() throws {
        let context = makeContext()
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
        session.endTime = Date()
        session.qualityScore = 0
        try context.save()

        #expect(!session.hasDisplayableScore, "qualityScore == 0 must not be displayable (awaiting analysis or HealthKit source-only)")
    }

    @Test("Score of 1.0 (sentinel for no sensor data) is not displayable")
    func sentinelScoreIsNotDisplayable() throws {
        let context = makeContext()
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
        session.endTime = Date()
        session.qualityScore = 1.0
        try context.save()

        #expect(!session.hasDisplayableScore, "qualityScore == 1.0 (sentinel) must not be displayable")
    }

    @Test("Numeric score without a Zeez estimate record is not displayable")
    func orphanScoreIsNotDisplayable() throws {
        let context = makeContext()
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
        session.endTime = Date()
        session.qualityScore = 72.0
        try context.save()

        #expect(!session.hasDisplayableScore, "A number without persisted Zeez estimate provenance must not be displayed")
    }

    // MARK: - HealthKit import

    @Test("HealthKit-imported session starts at qualityScore 0 with no SleepQualityScore entity")
    func healthKitSessionHasNoQualityScoreEntity() throws {
        let context = makeContext()
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
        session.endTime = Date()
        session.deviceIdentifier = "HealthKit Import"
        session.qualityScore = 0
        try context.save()

        let qualityScores = session.qualityScores?.allObjects as? [SleepQualityScore] ?? []
        #expect(qualityScores.isEmpty, "HealthKit import must not create a SleepQualityScore entity")
        #expect(!session.hasDisplayableScore, "HealthKit session with score 0 must not be displayable")
    }

    // MARK: - Mock data

    @Test("Debug mock session has a displayable qualityScore set by the generator")
    func mockSessionHasDisplayableQualityScore() throws {
        let context = makeContext()
        let generator = MockDataGenerator(context: context)
        generator.generateMockData(for: 1)

        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(format: "deviceIdentifier CONTAINS[c] %@", "Mock Data")
        let sessions = try context.fetch(request)

        #expect(!sessions.isEmpty)
        for session in sessions {
            #expect(session.hasDisplayableScore, "Mock sessions should always have a displayable quality score")
        }
    }

    // MARK: - Score-provenance distinctness

    @Test("SleepQualityScore entity distinguishes Zeez-estimated from unavailable score")
    func qualityScoreEntityDistinguishesSource() throws {
        let context = makeContext()
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
        session.endTime = Date()
        session.deviceIdentifier = "Manual Session"
        session.qualityScore = 72.0

        attachZeezEstimate(to: session, in: context)
        try context.save()

        let entities = session.qualityScores?.allObjects as? [SleepQualityScore] ?? []
        #expect(entities.count == 1, "One SleepQualityScore entity should be attached after analysis")
        #expect(entities.first?.calculationVersion?.contains("SleepAnalyzer") == true)
        #expect(session.hasDisplayableScore, "Session with a Zeez estimate must be displayable")
        #expect(session.hasZeezEstimatedScore)
    }

    @Test("Imported stages retain Apple Health provenance while Zeez stages are labeled experimental")
    func stageSourceDescriptionIdentifiesProvenance() {
        let context = makeContext()
        let imported = SleepSession(context: context)
        imported.deviceIdentifier = "HealthKit Import"

        let zeez = SleepSession(context: context)
        zeez.deviceIdentifier = "Local Tracking"

        #expect(imported.hasSourceReportedStages)
        #expect(imported.stageSourceDescription == "Reported by Apple Health")
        #expect(!zeez.hasSourceReportedStages)
        #expect(zeez.stageSourceDescription == "Experimental Zeez-estimated stages")
    }

    // MARK: - Trends aggregation

    @Test("Trends fetch excludes sessions with non-displayable scores")
    func trendsFetchExcludesNonDisplayableSessions() throws {
        let context = makeContext()

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
        let displayable = allSessions.filter { $0.hasDisplayableScore }

        #expect(displayable.count == 1, "Only sessions with score > 1.0 should be included in trend aggregates")
        #expect(displayable.first?.qualityScore == 78.0)
    }

    @Test("Watch payload states unavailable score and omits its numeric value")
    func watchPayloadOmitsUnavailableScore() throws {
        let context = makeContext()
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
        session.endTime = Date()
        session.qualityScore = 1.0
        try context.save()

        let payload = try #require(watchSleepSummaryPayload(for: session))
        #expect(payload["qualityAvailable"] as? Bool == false)
        #expect(payload["quality"] == nil)
    }

    @Test("Watch payload sends an available score explicitly")
    func watchPayloadIncludesAvailableScore() throws {
        let context = makeContext()
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
        session.endTime = Date()
        session.qualityScore = 84
        attachZeezEstimate(to: session, in: context)
        try context.save()

        let payload = try #require(watchSleepSummaryPayload(for: session))
        #expect(payload["qualityAvailable"] as? Bool == true)
        #expect(payload["quality"] as? Double == 84)
    }

    @Test("Dashboard quality preview renders unavailable without inventing a metric")
    func dashboardPreviewStatesUnavailableScore() {
        let context = makeContext()
        let session = SleepSession(context: context)
        session.qualityScore = 0

        let stat = SleepQualityPreviewStats.getRandomStat(from: session)
        #expect(stat?.label == "Score")
        #expect(stat?.value == "Unavailable")
    }

    @Test("Dashboard quality preview identifies available values as experimental Zeez estimates")
    func dashboardPreviewLabelsEstimatedScore() {
        let context = makeContext()
        let session = SleepSession(context: context)
        session.qualityScore = 84
        attachZeezEstimate(to: session, in: context)

        let stat = SleepQualityPreviewStats.getRandomStat(from: session)
        #expect(stat?.label == "Experimental Zeez Estimate")
        #expect(stat?.value == "84 pts")
    }
}
