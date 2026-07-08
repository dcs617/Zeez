import Testing
import CoreData
@testable import Zeez

/// End-of-session scoring honesty (second audit A7). Before the fix,
/// `endSession` wrote `hoursSlept × 10` into `qualityScore` — a fabricated
/// number whose nonzero value also excluded the session from the analysis
/// backlog, so Zeez-recorded sessions never earned a real estimate. Now the
/// score stays 0 (= awaiting analysis) and `SleepAnalyzer` runs after the
/// HealthKit heart-rate sync completes.
@Suite("Session end scoring (A7)", .serialized)
struct SleepSessionEndTests {

    /// The validator requires environmental readings covering ≥80% of the
    /// session (production sessions get them from `EnvironmentalMonitor`).
    @MainActor
    private func seedEnvironmentalCoverage(for session: SleepSession,
                                           from start: Date, to end: Date,
                                           in context: NSManagedObjectContext) {
        for fraction in [0.0, 0.5, 0.95] {
            let reading = EnvironmentalReading(context: context)
            reading.id = UUID()
            reading.timestamp = start.addingTimeInterval(end.timeIntervalSince(start) * fraction)
            reading.session = session
        }
    }

    @MainActor
    private func endSession(_ manager: SleepSessionManager, _ session: SleepSession) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.endSession(session) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @Test @MainActor
    func endSessionDoesNotFabricateAScore() async throws {
        let controller = PersistenceController(inMemory: true)
        let manager = SleepSessionManager(persistenceController: controller)
        let context = controller.container.viewContext

        // 20 minutes: long enough to pass validation (≥15 min), short enough
        // that the analyzer refuses it (<30 min) — so any score appearing on
        // this session could only come from a fabricated write.
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -20 * 60)
        session.isActive = true
        seedEnvironmentalCoverage(for: session, from: session.startTime!, to: Date(), in: context)
        try context.save()

        try await endSession(manager, session)
        #expect(session.qualityScore == 0, "endSession must leave 0 = awaiting analysis")

        // Negative assertion — give the post-sync analysis pipeline time to
        // (wrongly) write something before re-checking.
        try await Task.sleep(nanoseconds: 2_000_000_000)
        context.refresh(session, mergeChanges: true)
        #expect(session.qualityScore == 0)
        #expect((session.qualityScores?.count ?? 0) == 0)
        #expect(!session.hasDisplayableScore)
    }

    @Test @MainActor
    func endedSessionWithSensorDataGetsAPersistedEstimate() async throws {
        let controller = PersistenceController(inMemory: true)
        let manager = SleepSessionManager(persistenceController: controller)
        let context = controller.container.viewContext

        let start = Date(timeIntervalSinceNow: -8 * 3600)
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = start
        session.isActive = true

        // Seed sensor evidence across the night so stage analysis has real
        // input (a restless spike every 7th sample, calm otherwise).
        for i in 0..<96 {
            let timestamp = start.addingTimeInterval(Double(i) * 5 * 60)

            let movement = MovementData(context: context)
            movement.id = UUID()
            movement.timestamp = timestamp
            movement.magnitude = i % 7 == 0 ? 0.8 : 0.05
            movement.session = session

            let heartRate = HeartRateData(context: context)
            heartRate.id = UUID()
            heartRate.timestamp = timestamp
            heartRate.value = i % 7 == 0 ? 72 : 55
            heartRate.session = session
        }
        seedEnvironmentalCoverage(for: session, from: start, to: Date(), in: context)
        try context.save()

        try await endSession(manager, session)
        #expect(session.qualityScore == 0, "No score may exist before analysis lands")

        // The analyzer runs on a background context after the HealthKit sync
        // completion; the viewContext merges its save automatically.
        try await AlarmTestSupport.waitUntil("a persisted SleepQualityScore record") {
            var analyzed = false
            context.performAndWait {
                context.refresh(session, mergeChanges: true)
                analyzed = session.qualityScore > 1.0 && (session.qualityScores?.count ?? 0) > 0
            }
            return analyzed
        }
        #expect(session.hasDisplayableScore)
    }
}
