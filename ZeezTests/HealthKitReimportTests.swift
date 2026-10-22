import Testing
import CoreData
import HealthKit
@testable import Zeez

/// Re-import behaviour of the HealthKit importer (PARKED_CAPABILITIES §8a).
///
/// Each test drives the real session-writing path, `reconcileImportedSleepSessions`, against an
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
    private func runImport(_ samples: [ImportedSleepSample],
                           into controller: PersistenceController) throws -> SleepImportReconciliation {
        let context = controller.newBackgroundContext()
        return try context.performAndWait {
            try reconcileImportedSleepSessions(samples, in: context)
        }
    }

    /// A HealthKit session as a pre-v3 build stored it: stages with no sample identity.
    @discardableResult
    private func seedLegacySession(_ stages: [(String, Double, Double)], createdAt: Date,
                                   deviceIdentifier: String = AppConstants.DataProvenance.healthKitImport,
                                   in controller: PersistenceController) throws -> UUID {
        let context = controller.newBackgroundContext()
        return try context.performAndWait {
            let session = SleepSession(context: context)
            let id = UUID()
            session.id = id
            session.createdAt = createdAt
            session.deviceIdentifier = deviceIdentifier
            session.startTime = time(stages.map(\.1).min()!)
            session.endTime = time(stages.map(\.2).max()!)
            for (type, from, to) in stages {
                let stage = SleepStage(context: context)
                stage.id = UUID()
                stage.stageType = type
                stage.startTime = time(from)
                stage.endTime = time(to)
                stage.duration = (to - from) * 60
                stage.session = session
            }
            try context.save()
            return id
        }
    }

    private func storedSessionIDs(in controller: PersistenceController) throws -> [UUID] {
        let context = controller.newBackgroundContext()
        return try context.performAndWait {
            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            request.predicate = NSPredicate(format: "deviceIdentifier == %@",
                                            AppConstants.DataProvenance.healthKitImport)
            return try context.fetch(request).compactMap(\.id)
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

    // MARK: - Sample identity

    @Test("Imported stages record their Apple Health sample's uuid and source")
    func importedStagesRecordSampleIdentity() throws {
        let controller = PersistenceController(inMemory: true)
        let samples = watchNight() + [sample(.inBed, -10, 370, source: Self.phone)]
        try runImport(samples, into: controller)

        let context = controller.newBackgroundContext()
        let stored = try context.performAndWait {
            try context.fetch(SleepStage.fetchRequest()).map { ($0.healthKitSampleUUID, $0.sourceBundleIdentifier) }
        }
        let expected = Dictionary(uniqueKeysWithValues: samples.map { ($0.uuid, $0.sourceBundleIdentifier) })
        #expect(stored.count == samples.count)
        for (uuid, source) in stored {
            let uuid = try #require(uuid, "Every imported stage must carry its sample's uuid")
            #expect(expected[uuid] == source)
        }
    }

    // MARK: - Re-import of an unchanged night

    @Test("Re-importing the same samples stores the night once")
    func identicalReimportIsIdempotent() throws {
        let controller = PersistenceController(inMemory: true)
        let samples = watchNight()

        try runImport(samples, into: controller)
        let second = try runImport(samples, into: controller)

        let sessions = try storedSessions(in: controller)
        #expect(sessions.count == 1)
        #expect(sessions.first?.stages.count == 4)
        #expect(second == SleepImportReconciliation(), "An unchanged night is neither new nor updated")
    }

    // MARK: - Re-import of a night Apple Health changed

    @Test("A night Apple Health later extends at the end is updated on re-import")
    func nightExtendedAtEndIsUpdated() throws {
        let controller = PersistenceController(inMemory: true)
        let samples = watchNight()
        try runImport(samples, into: controller)

        // The Watch syncs the rest of the night after the first import.
        let second = try runImport(samples + [sample(.asleepCore, 360, 450)], into: controller)

        let sessions = try storedSessions(in: controller)
        #expect(sessions.count == 1)
        #expect(sessions.first?.end == time(450), "The re-imported night must end at 06:30, not stay truncated at 05:00")
        #expect(sessions.first?.stages.count == 5)
        #expect(second.inserted.isEmpty)
        #expect(second.updated.map(\.end) == [time(450)], "The update reports the night's new range")
    }

    @Test("A night Apple Health later extends earlier by more than 15 minutes is not duplicated")
    func nightExtendedEarlierIsNotDuplicated() throws {
        let controller = PersistenceController(inMemory: true)
        let samples = watchNight()
        try runImport(samples, into: controller)

        // An awake interval before sleep onset arrives later and moves the night's start to 22:30.
        try runImport([sample(.awake, -30, 0)] + samples, into: controller)

        let sessions = try storedSessions(in: controller)
        #expect(sessions.count == 1, "One night must stay one session, not two overlapping copies")
        #expect(sessions.first?.start == time(-30))
    }

    @Test("Filling the gap between two stored nights joins them, as a fresh import would")
    func gapFillJoinsStoredNights() throws {
        let controller = PersistenceController(inMemory: true)
        // 23:00–01:00 and 06:00–08:00 are five hours apart: two sessions.
        let early = sample(.asleepCore, 0, 120)
        let late = sample(.asleepCore, 420, 540)
        try runImport([early, late], into: controller)
        #expect(try storedSessions(in: controller).count == 2)

        try runImport([early, sample(.awake, 120, 420), late], into: controller)

        let sessions = try storedSessions(in: controller)
        #expect(sessions.count == 1)
        #expect(sessions.first?.stages.count == 3)
    }

    // MARK: - Absence is not deletion

    @Test("Samples a re-import does not return are kept")
    func missingSamplesAreKept() throws {
        let controller = PersistenceController(inMemory: true)
        let samples = watchNight()
        try runImport(samples, into: controller)

        // An import window that starts at 01:00 sees only the back half of the night.
        let second = try runImport(Array(samples.dropFirst(2)), into: controller)

        let sessions = try storedSessions(in: controller)
        #expect(sessions.first?.stages.count == 4)
        #expect(sessions.first?.start == time(0))
        #expect(second == SleepImportReconciliation())
    }

    @Test("A night a re-import does not return at all is kept")
    func missingNightIsKept() throws {
        let controller = PersistenceController(inMemory: true)
        try runImport(watchNight(), into: controller)

        // What HealthKit returns once read access is revoked: nothing, and no error.
        try runImport([], into: controller)

        #expect(try storedSessions(in: controller).count == 1)
    }

    // MARK: - Overlapping sources

    @Test("A second source that arrives later within 15 minutes is merged, not dropped")
    func laterSourceWithinMarginIsMerged() throws {
        let controller = PersistenceController(inMemory: true)
        let watchSamples = watchNight()
        try runImport(watchSamples, into: controller)

        // The iPhone's in-bed interval 22:50–05:10 reaches Apple Health after the first import.
        let inBed = sample(.inBed, -10, 370, source: Self.phone)
        try runImport([inBed] + watchSamples, into: controller)

        let sessions = try storedSessions(in: controller)
        #expect(sessions.count == 1)
        #expect(sessions.first?.stages.contains { $0.type == "inBed" } == true,
                "The later in-bed interval must reach the stored night")
    }

    @Test("A second source that arrives later and starts earlier does not duplicate the night")
    func laterSourceStartingEarlierIsNotDuplicated() throws {
        let controller = PersistenceController(inMemory: true)
        let watchSamples = watchNight()
        try runImport(watchSamples, into: controller)

        let inBed = sample(.inBed, -50, 370, source: Self.phone)
        try runImport([inBed] + watchSamples, into: controller)

        let sessions = try storedSessions(in: controller)
        #expect(sessions.count == 1, "Phone and Watch records of one night must be one session")
    }

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

    // MARK: - Stores written before model v3

    @Test("Pre-v3 stages are replaced by their identified copies, not duplicated")
    func legacyStagesAreReplacedByIdentifiedCopies() throws {
        let controller = PersistenceController(inMemory: true)
        let id = try seedLegacySession([("light", 0, 120), ("deep", 120, 180), ("light", 180, 300), ("rem", 300, 360)],
                                       createdAt: Self.night, in: controller)

        try runImport(watchNight(), into: controller)

        let sessions = try storedSessions(in: controller)
        #expect(sessions.count == 1)
        #expect(sessions.first?.stages.count == 4)
        #expect(try storedSessionIDs(in: controller) == [id], "The stored night keeps its id")
        let context = controller.newBackgroundContext()
        let unidentified = try context.performAndWait {
            try context.count(for: {
                let request: NSFetchRequest<SleepStage> = SleepStage.fetchRequest()
                request.predicate = NSPredicate(format: "healthKitSampleUUID == nil")
                return request
            }())
        }
        #expect(unidentified == 0)
    }

    @Test("A pre-v3 stage HealthKit no longer returns is kept")
    func unmatchedLegacyStageIsKept() throws {
        let controller = PersistenceController(inMemory: true)
        try seedLegacySession([("light", 0, 120), ("awake", 360, 370)], createdAt: Self.night, in: controller)

        try runImport([sample(.asleepCore, 0, 120)], into: controller)

        let stages = try #require(try storedSessions(in: controller).first).stages
        #expect(stages.map(\.type) == ["light", "awake"])
    }

    @Test("Duplicates left by the old 15-minute rule fold into the oldest session")
    func oldDuplicatesFoldIntoOldestSession() throws {
        let controller = PersistenceController(inMemory: true)
        let oldest = try seedLegacySession([("light", 0, 360)], createdAt: Self.night, in: controller)
        try seedLegacySession([("awake", -30, 0), ("light", 0, 360)],
                              createdAt: Self.night.addingTimeInterval(86_400), in: controller)

        let result = try runImport([sample(.awake, -30, 0), sample(.asleepCore, 0, 360)], into: controller)

        #expect(try storedSessionIDs(in: controller) == [oldest])
        let session = try #require(try storedSessions(in: controller).first)
        #expect(session.stages.map(\.type) == ["awake", "light"])
        #expect(session.start == time(-30))
        #expect(result.updated.count == 1)
    }

    // MARK: - What stays separate

    @Test("Two nights a day apart stay two sessions")
    func separateNightsStaySeparate() throws {
        let controller = PersistenceController(inMemory: true)
        let first = watchNight()
        let second = [sample(.asleepCore, 1440, 1800)]
        try runImport(first, into: controller)
        try runImport(first + second, into: controller)

        #expect(try storedSessions(in: controller).count == 2)
    }

    @Test("A Zeez-recorded session overlapping an imported night is never merged with it")
    func zeezRecordedSessionIsLeftAlone() throws {
        let controller = PersistenceController(inMemory: true)
        try seedLegacySession([("light", 0, 360)], createdAt: Self.night, deviceIdentifier: "iPhone", in: controller)

        try runImport(watchNight(), into: controller)

        let context = controller.newBackgroundContext()
        let counts = try context.performAndWait {
            let all = try context.fetch(SleepSession.fetchRequest())
            return (all.count, all.first { $0.deviceIdentifier == "iPhone" }?.sleepStages?.count)
        }
        #expect(counts.0 == 2)
        #expect(counts.1 == 1)
    }

    // MARK: - Related data

    @Test("Reported sessions are saved and resolvable from another context")
    func reportedSessionsAreResolvable() async throws {
        let controller = PersistenceController(inMemory: true)
        let result = try runImport(watchNight(), into: controller)
        let range = try #require(result.inserted.first)
        #expect(!range.sessionID.isTemporaryID)

        let other = controller.newBackgroundContext()
        let identifier = try await other.perform {
            (try other.existingObject(with: range.sessionID) as? SleepSession)?.deviceIdentifier
        }
        #expect(identifier == AppConstants.DataProvenance.healthKitImport,
                "Related-data callbacks resolve the session by object ID in their own context")
    }
}
