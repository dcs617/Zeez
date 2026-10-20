import Testing
import Foundation
import CoreData
@testable import Zeez

/// `ZeezScoreBreakdown` is the only place the Experimental Zeez Estimate explains itself
/// (`ZEEZ_SCORE_SPECIFICATION.md` §8). Its one hard rule: a breakdown is shown only when it
/// reproduces the stored score under the current specification version, so the explanation
/// can never disagree with the number beside it.
@Suite("Zeez score breakdown")
struct ZeezScoreBreakdownTests {

    private static let sessionEnd = Date(timeIntervalSinceReferenceDate: 800_000_000)

    // MARK: - Fixtures

    private func makeSession(in context: NSManagedObjectContext, asleepHours: Double = 8) -> SleepSession {
        let start = Self.sessionEnd.addingTimeInterval(-8 * 3600)
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = start
        session.endTime = Self.sessionEnd
        session.isActive = false

        // Deep 20% / Light 55% / REM 25% of asleep time, starting at t=0.
        var cursor = start
        let stageLength = asleepHours * 3600 / 20
        let plan = Array(repeating: "DEEP", count: 4)
                 + Array(repeating: "LIGHT", count: 11)
                 + Array(repeating: "REM", count: 5)
        for type in plan {
            let stage = SleepStage(context: context)
            stage.id = UUID()
            stage.stageType = type
            stage.startTime = cursor
            stage.endTime = cursor.addingTimeInterval(stageLength)
            stage.duration = stageLength
            stage.session = session
            cursor = cursor.addingTimeInterval(stageLength)
        }
        return session
    }

    /// Persists the estimate the way `SleepAnalyzer` does, optionally overriding what is stored.
    private func persistEstimate(for session: SleepSession, in context: NSManagedObjectContext,
                                 storedScore: Double? = nil,
                                 version: String = ZeezScore.version) throws {
        let metrics = try #require(SleepQualityCalculator(session: session, context: context).calculateMetrics())
        session.qualityScore = storedScore ?? metrics.overallScore

        let record = SleepQualityScore(context: context)
        record.id = UUID()
        record.timestamp = Self.sessionEnd
        record.overallScore = session.qualityScore
        record.calculationVersion = version
        record.confidenceScore = metrics.confidence
        record.session = session
    }

    // MARK: - Available

    @Test("A current estimate's breakdown lists every component in specification order and adds up")
    func breakdownReproducesStoredScore() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        try context.performAndWait {
            let session = makeSession(in: context, asleepHours: 4)
            try persistEstimate(for: session, in: context)

            guard case .available(let breakdown) = ZeezScoreBreakdown.make(for: session) else {
                Issue.record("A freshly persisted current-version estimate must have a breakdown")
                return
            }
            #expect(breakdown.entries.map(\.component) == ZeezScoreComponent.allCases)
            #expect(abs(breakdown.overallScore - session.qualityScore) < 0.0001)

            // The weighted entries must rebuild the composite, or the screen explains
            // a different number from the one it shows.
            let available = breakdown.entries.compactMap { entry in
                entry.result.score.map { (score: $0, weight: entry.component.weight) }
            }
            let weight = available.reduce(0.0) { $0 + $1.weight }
            let rebuilt = available.reduce(0.0) { $0 + $1.score * $1.weight } / weight
            #expect(abs(rebuilt - session.qualityScore) < 0.0001)
            #expect(breakdown.entries.first { $0.component == .sleepOpportunity }?.result == .available(50))
        }
    }

    @Test("An unavailable component is listed as unavailable, never as a number")
    func unavailableComponentIsListedWithItsReason() {
        let breakdown = ZeezScoreBreakdown(
            entries: [
                .init(component: .duration, result: .available(100)),
                .init(component: .latency, result: .unavailable(.noAsleepIntervals))
            ],
            overallScore: 100,
            inputCoverage: 95
        )
        #expect(breakdown.hasUnavailableComponents)
        #expect(breakdown.entries.last?.result.score == nil)
        #expect(ZeezScoreBreakdownView.accessibilityValue(for: .unavailable(.noAsleepIntervals))
                    .hasPrefix("Not available"))
    }

    @Test("An end-to-end analyzed session gets a breakdown")
    func analyzedSessionHasBreakdown() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let objectID = try context.performAndWait {
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = Date(timeIntervalSinceNow: -7.5 * 3600)
            session.endTime = Date()
            session.deviceIdentifier = "Manual Session"
            session.isActive = false
            for i in 0..<10 {
                let hr = HeartRateData(context: context)
                hr.id = UUID()
                hr.timestamp = session.startTime!.addingTimeInterval(Double(i) * 2700)
                hr.value = 60
                hr.session = session
            }
            try context.save()
            return session.objectID
        }
        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: objectID, container: controller.container)

        let bgContext = controller.container.newBackgroundContext()
        let (hasScore, hasBreakdown) = try await bgContext.perform {
            let session = try #require(try bgContext.existingObject(with: objectID) as? SleepSession)
            guard case .available = ZeezScoreBreakdown.make(for: session) else {
                return (session.hasDisplayableScore, false)
            }
            return (session.hasDisplayableScore, true)
        }
        try #require(hasScore, "Fixture must produce a displayable estimate for this test to mean anything")
        #expect(hasBreakdown, "The analyzer's own output must reproduce under the current version")
    }

    // MARK: - Unavailable

    @Test("The sentinel score has nothing to explain")
    func sentinelHasNoBreakdown() {
        let context = PersistenceController(inMemory: true).container.viewContext
        context.performAndWait {
            let session = makeSession(in: context)
            session.qualityScore = 1.0
            #expect(ZeezScoreBreakdown.make(for: session) == .unavailable(.noEstimate))
        }
    }

    @Test("An estimate from an earlier specification version is not re-explained under the current one")
    func earlierVersionHasNoBreakdown() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        try context.performAndWait {
            let session = makeSession(in: context)
            try persistEstimate(for: session, in: context, version: "SleepAnalyzer-2.0")
            #expect(ZeezScoreBreakdown.make(for: session) == .unavailable(.earlierVersion))
        }
    }

    @Test("A stored score the stages no longer reproduce gets no breakdown")
    func mismatchedScoreHasNoBreakdown() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        try context.performAndWait {
            let session = makeSession(in: context)  // recomputes to 100
            try persistEstimate(for: session, in: context, storedScore: 72)
            #expect(ZeezScoreBreakdown.make(for: session) == .unavailable(.notReproducible))
        }
    }

    // MARK: - Wording (claims contract)

    @Test("Component names describe calculations, not sleep quality or efficiency")
    func componentNamesAvoidUnsupportedClaims() {
        let prohibited = ["quality", "efficiency", "fall asleep", "fell asleep", "recovery", "healthy"]
        for component in ZeezScoreComponent.allCases {
            let name = component.displayName.lowercased()
            for phrase in prohibited {
                #expect(!name.contains(phrase), "\(component) is named \"\(component.displayName)\"")
            }
            let explanation = component.explanation.lowercased()
            for phrase in ["quality", "fall asleep", "fell asleep", "recovery", "healthy"] {
                #expect(!explanation.contains(phrase), "\(component) explanation contains \"\(phrase)\"")
            }
        }
    }

    @Test("A component score reaches VoiceOver with its experimental label")
    func accessibilityValueCarriesExperimentalLabel() {
        let value = ZeezScoreBreakdownView.accessibilityValue(for: .available(85))
        #expect(value.contains("Experimental Zeez estimate"))
        #expect(value.contains("85"))
    }
}
