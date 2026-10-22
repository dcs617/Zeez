import Foundation
import HealthKit
import CoreData
import os.log

// MARK: - Import results

/// Outcome of one related-data sub-import (heart rate, respiratory rate).
///
/// These used to be fire-and-forget: the importer reported "imported N sessions" while a
/// sub-import could fail silently, leaving sessions without the physiological data the
/// user expected. Each sub-import now reports for itself.
enum RelatedDataOutcome: Equatable {
    /// Completed; `readingCount` rows were stored across all imported sessions.
    case imported(readingCount: Int)
    /// The quantity type is not available on this device, so nothing was attempted.
    case unavailable
    /// At least one session's sub-import failed. Sessions themselves were still saved.
    case failed(String)

    var didFail: Bool {
        if case .failed = self { return true }
        return false
    }
}

/// What `importSleepData` accomplished. Sessions are saved before related data is fetched,
/// so a related-data failure never discards imported sessions — it is reported alongside.
struct HealthKitImportResult: Equatable {
    let sessionCount: Int
    let heartRate: RelatedDataOutcome
    let respiratory: RelatedDataOutcome

    var hasPartialFailure: Bool {
        heartRate.didFail || respiratory.didFail
    }
}

// MARK: - Testable grouping helper (no HealthKit dependency)

/// Anything with a start and an end that can be clustered into nights.
protocol SleepTimedInterval {
    var start: Date { get }
    var end: Date { get }
}

/// A minimal interval representation used to cluster sleep samples without coupling tests to HealthKit types.
struct SleepSampleInterval: SleepTimedInterval {
    let start: Date
    let end: Date
}

/// One HealthKit sleep sample, reduced to the values Zeez stores.
///
/// The importer converts `HKCategorySample`s to this at the HealthKit boundary, so the
/// session-writing path runs — and is tested — without a health store. Tests can also set
/// `uuid` and `sourceBundleIdentifier`, which HealthKit fixes on a real sample.
struct ImportedSleepSample: SleepTimedInterval, Equatable {
    /// `HKObject.uuid` — stable for as long as the sample exists in HealthKit. An edit in
    /// the Health app is a delete plus a new sample with a new uuid.
    let uuid: UUID
    /// An `HKCategoryValueSleepAnalysis` raw value.
    let value: Int
    let start: Date
    let end: Date
    /// `HKSource.bundleIdentifier` of the app or device that wrote the sample.
    let sourceBundleIdentifier: String?
}

extension ImportedSleepSample {
    init(_ sample: HKCategorySample) {
        self.init(uuid: sample.uuid,
                  value: sample.value,
                  start: sample.startDate,
                  end: sample.endDate,
                  sourceBundleIdentifier: sample.sourceRevision.source.bundleIdentifier)
    }
}

/// Groups intervals into contiguous sessions, starting a new group whenever consecutive
/// intervals are separated by more than `gapThreshold`.
///
/// Works directly on the intervals rather than a date-keyed lookup, which would trap when
/// several samples share a start date (overlapping in-bed and asleep intervals, or data
/// from multiple sources). Calendar-day grouping is intentionally avoided so a session from
/// 11 pm to 7 am is one session rather than split at midnight.
func groupIntervalsIntoSessions<Interval: SleepTimedInterval>(
    _ intervals: [Interval],
    gapThreshold: TimeInterval = 4 * 3600
) -> [[Interval]] {
    let sorted = intervals.sorted { $0.start < $1.start }
    var groups: [[Interval]] = []
    var currentGroup: [Interval] = []
    var currentEnd: Date?

    for interval in sorted {
        if let end = currentEnd, interval.start.timeIntervalSince(end) > gapThreshold {
            if !currentGroup.isEmpty { groups.append(currentGroup) }
            currentGroup = [interval]
        } else {
            currentGroup.append(interval)
        }
        currentEnd = max(currentEnd ?? interval.end, interval.end)
    }
    if !currentGroup.isEmpty { groups.append(currentGroup) }
    return groups
}

/// Saves a newly imported parent before related-data callbacks try to resolve it in another
/// context. A permanent ID alone is not visible through the persistent store until save.
func saveImportedSessionForRelatedData(
    _ session: SleepSession,
    in context: NSManagedObjectContext
) throws -> NSManagedObjectID {
    if session.objectID.isTemporaryID {
        try context.obtainPermanentIDs(for: [session])
    }
    try context.save()
    return session.objectID
}

/// Groups fetched sleep samples into nights and writes one `SleepSession` per night that
/// is not already stored. Must run on `context`'s queue. Returns the saved sessions whose
/// heart-rate and respiratory samples still need importing.
///
/// A free function, like `saveImportedSessionForRelatedData`, so tests can drive the real
/// session-writing path against an in-memory store without a HealthKit store.
func persistImportedSleepSessions(
    from sleepSamples: [ImportedSleepSample],
    in context: NSManagedObjectContext
) throws -> [(sessionID: NSManagedObjectID, start: Date, end: Date)] {
    var pendingRelatedImports: [(sessionID: NSManagedObjectID, start: Date, end: Date)] = []

    let sampleGroups = groupIntervalsIntoSessions(sleepSamples)

    ZeezLogger.info(ZeezLogger.coreData, "Grouped \(sleepSamples.count) samples into \(sampleGroups.count) sessions")

    for group in sampleGroups {
        guard let groupStart = group.map(\.start).min(),
              let groupEnd = group.map(\.end).max() else { continue }

        // Idempotency: skip if a HealthKit session with a matching start already exists
        if HealthKitDataImporter.sessionExists(start: groupStart, in: context) {
            ZeezLogger.debug(ZeezLogger.coreData, "Skipping duplicate session starting at \(groupStart)")
            continue
        }

        guard let session = HealthKitDataImporter.createSleepSession(from: group, start: groupStart, end: groupEnd, context: context) else {
            continue
        }

        // Related-data callbacks use separate contexts; save the parent before
        // starting either query so the object ID is resolvable in those contexts.
        let sessionID = try saveImportedSessionForRelatedData(session, in: context)

        // Related data is fetched after the parent sessions are saved.
        // Only the saved objectID crosses context-queue boundaries.
        pendingRelatedImports.append((sessionID, groupStart, groupEnd))

        ZeezLogger.debug(ZeezLogger.coreData, "Imported session \(pendingRelatedImports.count) (\(groupStart) – \(groupEnd))")
    }

    if context.hasChanges {
        try context.save()
        ZeezLogger.info(ZeezLogger.coreData, "Saved \(pendingRelatedImports.count) imported session(s)")
    }
    return pendingRelatedImports
}

/// Maps a HealthKit sleep value to the source-reported representation stored by Zeez.
func healthKitSleepStageType(for value: Int) -> String {
    switch value {
    case HKCategoryValueSleepAnalysis.awake.rawValue:
        return "awake"
    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
        return "light"
    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
        return "asleepUnspecified"
    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
        return "deep"
    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
        return "rem"
    case HKCategoryValueSleepAnalysis.inBed.rawValue:
        return "inBed"
    default:
        return "unknown"
    }
}

// MARK: - HealthKitDataImporter

class HealthKitDataImporter {
    static let shared = HealthKitDataImporter()

    private let healthStore = HKHealthStore()
    private let persistenceController = PersistenceController.shared
    private let errorManager = ErrorManager.shared

    private init() {}

    // MARK: - Authorization

    func requestFullAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HealthKitAuthorization.isAvailable else {
            ZeezLogger.error(ZeezLogger.error, "HealthKit is not available on this device")
            completion(false, AppError.healthKitNotAvailable)
            return
        }

        ZeezLogger.info(ZeezLogger.coreData, "Requesting HealthKit authorization for \(HealthKitAuthorization.readTypes.count) data types")

        HealthKitAuthorization.request(using: healthStore) { success, error in
            if let error = error {
                ZeezLogger.error(ZeezLogger.error, "HealthKit authorization error: \(error.localizedDescription)")
            } else {
                ZeezLogger.info(ZeezLogger.coreData, "HealthKit authorization completed: \(success)")
            }
            DispatchQueue.main.async { completion(success, error) }
        }
    }

    // MARK: - Import Sleep Data

    /// Imports sleep sessions and their related physiological data.
    ///
    /// Completion fires only once every sub-import has finished, so callers can report
    /// per-type outcomes rather than assuming success (second-audit B10).
    func importSleepData(from startDate: Date, to endDate: Date,
                         completion: @escaping (Result<HealthKitImportResult, Error>) -> Void) {
        ZeezLogger.info(ZeezLogger.coreData, "Starting HealthKit sleep data import from \(startDate) to \(endDate)")

        fetchSleepAnalysisData(from: startDate, to: endDate) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let sleepData):
                self.processSleepData(sleepData, completion: completion)
            case .failure(let error):
                ZeezLogger.error(ZeezLogger.error, "Failed to fetch sleep data from HealthKit: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    private func fetchSleepAnalysisData(from startDate: Date, to endDate: Date,
                                        completion: @escaping (Result<[ImportedSleepSample], Error>) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(.failure(AppError.healthKitNotAvailable))
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            if let error = error { completion(.failure(error)); return }
            let sleepSamples = (samples ?? []).compactMap { $0 as? HKCategorySample }.map(ImportedSleepSample.init)
            ZeezLogger.info(ZeezLogger.coreData, "Found \(sleepSamples.count) HealthKit sleep samples")
            completion(.success(sleepSamples))
        }
        healthStore.execute(query)
    }

    private func processSleepData(_ sleepSamples: [ImportedSleepSample],
                                  completion: @escaping (Result<HealthKitImportResult, Error>) -> Void) {
        let context = persistenceController.container.newBackgroundContext()

        context.perform {
            do {
                let pendingRelatedImports = try persistImportedSleepSessions(from: sleepSamples, in: context)

                let sessionCount = pendingRelatedImports.count
                self.importRelatedData(for: pendingRelatedImports) { heartRate, respiratory in
                    let result = HealthKitImportResult(sessionCount: sessionCount,
                                                       heartRate: heartRate,
                                                       respiratory: respiratory)
                    DispatchQueue.main.async { completion(.success(result)) }
                }

            } catch {
                ZeezLogger.error(ZeezLogger.error, "Failed to save imported sleep data: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// Runs both sub-imports for every session and reports one outcome per data type.
    ///
    /// Sessions are already saved by the time this runs, so a sub-import failure degrades
    /// the report rather than the import.
    private func importRelatedData(
        for sessions: [(sessionID: NSManagedObjectID, start: Date, end: Date)],
        completion: @escaping (RelatedDataOutcome, RelatedDataOutcome) -> Void
    ) {
        guard !sessions.isEmpty else {
            completion(.imported(readingCount: 0), .imported(readingCount: 0))
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var heartRateResults: [Result<Int, Error>] = []
        var respiratoryResults: [Result<Int, Error>] = []

        for session in sessions {
            group.enter()
            importHeartRateData(sessionID: session.sessionID, from: session.start, to: session.end) { result in
                lock.withLock { heartRateResults.append(result) }
                group.leave()
            }

            group.enter()
            importRespiratoryData(sessionID: session.sessionID, from: session.start, to: session.end) { result in
                lock.withLock { respiratoryResults.append(result) }
                group.leave()
            }
        }

        group.notify(queue: .global(qos: .userInitiated)) {
            completion(Self.summarize(heartRateResults), Self.summarize(respiratoryResults))
        }
    }

    /// Any failure makes the whole type a partial failure — the user is told which data is
    /// incomplete rather than shown a success that silently lost a night's samples.
    private static func summarize(_ results: [Result<Int, Error>]) -> RelatedDataOutcome {
        var total = 0
        var firstFailure: Error?

        for result in results {
            switch result {
            case .success(let count):
                total += count
            case .failure(let error):
                if firstFailure == nil { firstFailure = error }
            }
        }

        if let firstFailure {
            if let appError = firstFailure as? AppError, appError == .healthKitNotAvailable, total == 0 {
                return .unavailable
            }
            return .failed(firstFailure.localizedDescription)
        }
        return .imported(readingCount: total)
    }

    // MARK: - Session Creation

    fileprivate static func createSleepSession(from samples: [ImportedSleepSample], start: Date, end: Date,
                                               context: NSManagedObjectContext) -> SleepSession? {
        guard !samples.isEmpty else { return nil }

        guard let coordinator = context.persistentStoreCoordinator, !coordinator.persistentStores.isEmpty else {
            ZeezLogger.error(ZeezLogger.error, "Core Data context has no persistent stores")
            return nil
        }

        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = start
        session.endTime = end
        session.isActive = false
        session.createdAt = Date()
        session.modifiedAt = Date()
        session.deviceIdentifier = AppConstants.DataProvenance.healthKitImport

        for sample in samples {
            let sleepStage = SleepStage(context: context)
            sleepStage.id = UUID()
            sleepStage.startTime = sample.start
            sleepStage.endTime = sample.end
            sleepStage.duration = sample.end.timeIntervalSince(sample.start)
            sleepStage.confidence = 85.0
            sleepStage.healthKitSampleUUID = sample.uuid
            sleepStage.sourceBundleIdentifier = sample.sourceBundleIdentifier

            sleepStage.stageType = healthKitSleepStageType(for: sample.value)
            if sleepStage.stageType == "unknown" {
                ZeezLogger.debug(ZeezLogger.coreData, "Unknown HealthKit sleep value: \(sample.value)")
            }

            sleepStage.session = session
        }

        // Record source-reported stages; qualityScore remains unavailable until an
        // independent scoring source writes a displayable score.
        ZeezLogger.debug(ZeezLogger.coreData, "Created HealthKit session \(start) – \(end), \(samples.count) stages")
        return session
    }

    // MARK: - Idempotency

    /// Returns `true` if a HealthKit-imported session with a start time within 15 minutes
    /// of `start` already exists, preventing duplicates on re-import.
    fileprivate static func sessionExists(start: Date, in context: NSManagedObjectContext) -> Bool {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        let margin: TimeInterval = 15 * 60
        request.predicate = NSPredicate(
            format: "deviceIdentifier == %@ AND startTime >= %@ AND startTime <= %@",
            AppConstants.DataProvenance.healthKitImport,
            Date(timeInterval: -margin, since: start) as NSDate,
            Date(timeInterval: margin, since: start) as NSDate
        )
        request.fetchLimit = 1
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    // MARK: - Related Data Import (concurrency-safe)

    /// Import heart rate samples for the session identified by `sessionID`.
    ///
    /// Accepts an `NSManagedObjectID` instead of a `SleepSession` to avoid crossing
    /// Core Data context-queue boundaries with a managed object reference.
    private func importHeartRateData(sessionID: NSManagedObjectID, from startTime: Date, to endTime: Date,
                                     completion: @escaping (Result<Int, Error>) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(.failure(AppError.healthKitNotAvailable))
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let self else {
                completion(.failure(AppError.dataProcessingFailed))
                return
            }
            if let error = error {
                ZeezLogger.error(ZeezLogger.error, "Failed to fetch heart rate data: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            // Bucket before persisting: a dense night would otherwise write thousands of
            // rows that every session read then faults in. See HeartRateDownsampler.
            let unit = HKUnit(from: "count/min")
            let sourceSamples = (samples ?? []).compactMap { $0 as? HKQuantitySample }.map {
                HeartRateDownsampler.Sample(
                    timestamp: $0.startDate,
                    value: $0.quantity.doubleValue(for: unit),
                    deviceType: $0.device?.name
                )
            }
            let readings = HeartRateDownsampler.downsample(sourceSamples)
            ZeezLogger.debug(ZeezLogger.coreData, "Heart rate: \(sourceSamples.count) samples → \(readings.count) stored readings")

            let bgContext = self.persistenceController.container.newBackgroundContext()
            bgContext.perform {
                guard let session = try? bgContext.existingObject(with: sessionID) as? SleepSession else {
                    completion(.failure(AppError.dataProcessingFailed))
                    return
                }
                for reading in readings {
                    let heartRate = HeartRateData(context: bgContext)
                    heartRate.id = UUID()
                    heartRate.timestamp = reading.timestamp
                    heartRate.value = reading.value
                    heartRate.deviceType = reading.deviceType ?? "Apple Watch"
                    heartRate.confidence = 90.0
                    heartRate.session = session
                }
                do {
                    try bgContext.save()
                    completion(.success(readings.count))
                } catch {
                    ZeezLogger.error(ZeezLogger.error, "Failed to save heart rate data: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
        healthStore.execute(query)
    }

    /// Import respiratory samples for the session identified by `sessionID`.
    private func importRespiratoryData(sessionID: NSManagedObjectID, from startTime: Date, to endTime: Date,
                                       completion: @escaping (Result<Int, Error>) -> Void) {
        guard let respiratoryType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else {
            completion(.failure(AppError.healthKitNotAvailable))
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startTime, end: endTime, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: respiratoryType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, error in
            guard let self else {
                completion(.failure(AppError.dataProcessingFailed))
                return
            }
            if let error = error {
                ZeezLogger.error(ZeezLogger.error, "Failed to fetch respiratory data: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            let quantitySamples = (samples ?? []).compactMap { $0 as? HKQuantitySample }
            let bgContext = self.persistenceController.container.newBackgroundContext()
            bgContext.perform {
                guard let session = try? bgContext.existingObject(with: sessionID) as? SleepSession else {
                    completion(.failure(AppError.dataProcessingFailed))
                    return
                }
                quantitySamples.forEach { sample in
                    let respiratoryData = RespiratoryData(context: bgContext)
                    respiratoryData.id = UUID()
                    respiratoryData.timestamp = sample.startDate
                    respiratoryData.respiratoryRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    respiratoryData.deviceType = sample.device?.name ?? "Apple Watch"
                    respiratoryData.confidence = 85.0
                    respiratoryData.session = session
                }
                do {
                    try bgContext.save()
                    completion(.success(quantitySamples.count))
                } catch {
                    ZeezLogger.error(ZeezLogger.error, "Failed to save respiratory data: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
        healthStore.execute(query)
    }
}
