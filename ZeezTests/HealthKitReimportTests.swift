import Testing
import CoreData
import HealthKit
@testable import Zeez

/// Re-import behaviour of the HealthKit importer (PARKED_CAPABILITIES §8a).
///
/// Each test drives the real session-writing path, `persistImportedSleepSessions`, against an
/// in-memory store. Passing the same `ImportedSleepSample` to two imports models HealthKit
/// returning the same sample twice (same `uuid`); a fresh one models a new or edited sample.
@Suite("HealthKit re-import")
struct HealthKitReimportTests {

    // MARK: - Fixtures

    /// 2026-10-01 23:00 UTC — a fixed night so assertions never depend on "now".
    private static let night = Date(timeIntervalSince1970: 1_790_895_600)

    private static let watch = "com.apple.health.5F2C1E9A-0B3D-4C6E-9A1F-2D7B8C4E6A10"
    private static let phone = "com.apple.health"

    /// A sleep sample `from`–`to` minutes after 23:00.
    private func sample(_ value: HKCategoryValueSleepAnalysis, _ from: Double, _ to: Double,
                        source: String = watch) -> ImportedSleepSample {
        ImportedSleepSample(uuid: UUID(), value: value.rawValue,
                            start: time(from), end: time(to),
                            sourceBundleIdentifier: source)
    }

    private func time(_ minutes: Double) -> Date {
        Self.night.addingTimeInterval(minutes * 60)
    }

    /// A Watch night 23:00–05:00: core, deep, core, REM.
    private func watchNight() -> [ImportedSleepSample] {
        [sample(.asleepCore, 0, 120), sample(.asleepDeep, 120, 180),
         sample(.asleepCore, 180, 300), sample(.asleepREM, 300, 360)]
    }

    private struct StoredStage: Equatable {
        let type: String
        let start: Date
        let end: Date
    }

    private struct StoredSession {
        let start: Date
        let end: Date
        let stages: [StoredStage]
    }

    @discardableResult
    private func runImport(_ samples: [ImportedSleepSample], into controller: PersistenceController) throws -> Int {
        let context = controller.newBackgroundContext()
        return try context.performAndWait {
            try persistImportedSleepSessions(from: samples, in: context).count
        }
    }

    private func storedSessions(in controller: PersistenceController) throws -> [StoredSession] {
        let context = controller.newBackgroundContext()
        return try context.performAndWait {
            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            request.predicate = NSPredicate(format: "deviceIdentifier == %@",
                                            AppConstants.DataProvenance.healthKitImport)
            request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: true)]
            return try context.fetch(request).map { session in
                let stages = (session.sleepStages as? Set<SleepStage> ?? [])
                    .map { StoredStage(type: $0.stageType ?? "", start: $0.startTime!, end: $0.endTime!) }
                    .sorted { ($0.start, $0.type) < ($1.start, $1.type) }
                return StoredSession(start: session.startTime!, end: session.endTime!, stages: stages)
            }
        }
    }

    // MARK: - Re-import of an unchanged night

    @Test("Re-importing the same samples stores the night once")
    func identicalReimportIsIdempotent() throws {
        let controller = PersistenceController(inMemory: true)
        let samples = watchNight()

        try runImport(samples, into: controller)
        let secondImportCount = try runImport(samples, into: controller)

        let sessions = try storedSessions(in: controller)
        #expect(sessions.count == 1)
        #expect(sessions.first?.stages.count == 4)
        #expect(secondImportCount == 0, "An unchanged night must not be reported as imported again")
    }

    // MARK: - Overlapping sources

    @Test("Two sources in one import form one session")
    func twoSourcesInOneImportFormOneSession() throws {
        let controller = PersistenceController(inMemory: true)
        try runImport([sample(.inBed, -50, 370, source: Self.phone)] + watchNight(), into: controller)

        let sessions = try storedSessions(in: controller)
        #expect(sessions.count == 1)
        #expect(sessions.first?.stages.count == 5)
    }

    /// Characterization: what the claims contract yields when two sources both report *asleep*
    /// for one night. "Time asleep" is the union of asleep intervals across everything imported,
    /// and conflicting stage types make composition unavailable rather than guessed. Daniel
    /// confirmed this union policy on 2026-10-22; a per-night preferred source would need a
    /// contract amendment first.
    @Test("Two asleep-reporting sources: time asleep is their union, composition is unavailable")
    func twoAsleepSourcesUnionAndConflict() throws {
        let controller = PersistenceController(inMemory: true)
        // Watch: core 23:30–06:30 (7 h). Another app: unspecified asleep 23:00–07:00 (8 h).
        try runImport([sample(.asleepCore, 30, 450),
                       sample(.asleepUnspecified, 0, 480, source: Self.phone)], into: controller)

        let session = try #require(try storedSessions(in: controller).first)
        let metrics = DerivedSleepMetrics.calculate(
            startTime: session.start, endTime: session.end, isAppleHealthSource: true,
            stages: session.stages.map {
                SleepMetricStageInterval(type: $0.type, startTime: $0.start, endTime: $0.end,
                                         duration: $0.end.timeIntervalSince($0.start))
            })

        let asleep = try #require(metrics.qualifiedAsleepDuration.value)
        #expect(abs(asleep - 8 * 3600) < 1,
                "Union across sources: 8 h, which neither the Watch (7 h) nor any one stage row reports")
        if case .unavailable(let reason) = metrics.asleepStageComposition {
            #expect(reason == .conflictingAsleepIntervals)
        } else {
            Issue.record("Overlapping core/unspecified intervals should make composition unavailable")
        }
    }
}
