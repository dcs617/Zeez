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
    /// Nights that were not stored before.
    let sessionCount: Int
    let heartRate: RelatedDataOutcome
    let respiratory: RelatedDataOutcome
    /// Stored nights Apple Health changed (§8a).
    var updatedSessionCount = 0
    /// Stored nights removed because Apple Health deleted them.
    var removedSessionCount = 0
    /// Nights found in the import window, changed or not — tells "already up to date" apart
    /// from "Apple Health has no sleep data".
    var fetchedNightCount = 0

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
    gapThreshold: TimeInterval = sleepSessionGapThreshold
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
    private let anchorStore = HealthKitSleepAnchorStore()

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

    /// Imports sleep sessions and their related physiological data, and applies sleep samples
    /// deleted in Apple Health since the last import.
    ///
    /// Completion fires only once every sub-import has finished, so callers can report
    /// per-type outcomes rather than assuming success (second-audit B10).
    func importSleepData(from startDate: Date, to endDate: Date,
                         completion: @escaping (Result<HealthKitImportResult, Error>) -> Void) {
        ZeezLogger.info(ZeezLogger.coreData, "Starting HealthKit sleep data import from \(startDate) to \(endDate)")

        let storedAnchor = anchorStore.load()
        fetchDeletedSleepSamples(since: storedAnchor) { [weak self] deletions in
            guard let self else { return }
            self.fetchSleepAnalysisData(from: startDate, to: endDate) { result in
                switch result {
                case .success(let window):
                    let deleted: Set<UUID>
                    if case .success(let feed)? = deletions {
                        deleted = feed.deleted
                    } else {
                        // Not applying deletions is safe: the anchor stays put, so they are
                        // reported again by the next import.
                        deleted = []
                    }
                    let anchor = nextSleepAnchor(stored: storedAnchor,
                                                 deletionQuery: deletions?.map { $0.anchor },
                                                 windowAnchor: window.anchor)
                    self.processSleepData(window.samples, deletedSampleUUIDs: deleted,
                                          anchorToSave: anchor, completion: completion)
                case .failure(let error):
                    ZeezLogger.error(ZeezLogger.error, "Failed to fetch sleep data from HealthKit: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }

    /// Sleep samples deleted from HealthKit since `anchor`, wherever they fall in time.
    ///
    /// No predicate: HealthKit does not document whether a date predicate filters deleted
    /// objects, and they carry no dates of their own. Deletions of samples Zeez never stored
    /// are ignored by the reconciler. Completes with nil when there is no anchor yet — nothing
    /// identified has been stored, so there is nothing to have missed.
    private func fetchDeletedSleepSamples(
        since anchor: HKQueryAnchor?,
        completion: @escaping (Result<(deleted: Set<UUID>, anchor: HKQueryAnchor?), Error>?) -> Void
    ) {
        guard let anchor else {
            completion(nil)
            return
        }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(.failure(AppError.healthKitNotAvailable))
            return
        }

        let query = HKAnchoredObjectQuery(type: sleepType, predicate: nil, anchor: anchor,
                                          limit: HKObjectQueryNoLimit) { _, _, deletedObjects, newAnchor, error in
            if let error {
                ZeezLogger.error(ZeezLogger.error, "Failed to fetch deleted sleep samples: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            let deleted = Set((deletedObjects ?? []).map(\.uuid))
            ZeezLogger.info(ZeezLogger.coreData, "HealthKit reports \(deleted.count) sleep sample(s) deleted since the last import")
            completion(.success((deleted, newAnchor)))
        }
        healthStore.execute(query)
    }

    /// The import window's sleep samples, and the anchor HealthKit returned with them.
    ///
    /// An anchored query rather than a plain sample query only so that a first import comes
    /// back with an anchor to start the deletions feed from.
    private func fetchSleepAnalysisData(
        from startDate: Date, to endDate: Date,
        completion: @escaping (Result<(samples: [ImportedSleepSample], anchor: HKQueryAnchor?), Error>) -> Void
    ) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(.failure(AppError.healthKitNotAvailable))
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKAnchoredObjectQuery(type: sleepType, predicate: predicate, anchor: nil,
                                          limit: HKObjectQueryNoLimit) { _, samples, _, newAnchor, error in
            if let error { completion(.failure(error)); return }
            let sleepSamples = (samples ?? []).compactMap { $0 as? HKCategorySample }.map(ImportedSleepSample.init)
            ZeezLogger.info(ZeezLogger.coreData, "Found \(sleepSamples.count) HealthKit sleep samples")
            completion(.success((sleepSamples, newAnchor)))
        }
        healthStore.execute(query)
    }

    private func processSleepData(_ sleepSamples: [ImportedSleepSample],
                                  deletedSampleUUIDs: Set<UUID>,
                                  anchorToSave: HKQueryAnchor?,
                                  completion: @escaping (Result<HealthKitImportResult, Error>) -> Void) {
        let context = persistenceController.container.newBackgroundContext()

        context.perform {
            do {
                let reconciliation = try reconcileImportedSleepSessions(
                    sleepSamples, deletedSampleUUIDs: deletedSampleUUIDs, in: context
                )
                // Only now that the deletions it covers are saved (see HealthKitSleepAnchorStore).
                if let anchorToSave { self.anchorStore.save(anchorToSave) }

                // A changed night's range moved, so its readings are fetched afresh too.
                self.importRelatedData(for: reconciliation.inserted + reconciliation.updated) { heartRate, respiratory in
                    let result = HealthKitImportResult(sessionCount: reconciliation.inserted.count,
                                                       heartRate: heartRate,
                                                       respiratory: respiratory,
                                                       updatedSessionCount: reconciliation.updated.count,
                                                       removedSessionCount: reconciliation.removedCount,
                                                       fetchedNightCount: reconciliation.fetchedNightCount)
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
        for sessions: [ImportedSessionRange],
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
                do {
                    completion(.success(try storeHeartRateReadings(readings, forSessionID: sessionID, in: bgContext)))
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

            let unit = HKUnit(from: "count/min")
            let readings = (samples ?? []).compactMap { $0 as? HKQuantitySample }.map {
                ImportedRespiratoryReading(timestamp: $0.startDate,
                                           rate: $0.quantity.doubleValue(for: unit),
                                           deviceType: $0.device?.name)
            }
            let bgContext = self.persistenceController.container.newBackgroundContext()
            bgContext.perform {
                do {
                    completion(.success(try storeRespiratoryReadings(readings, forSessionID: sessionID, in: bgContext)))
                } catch {
                    ZeezLogger.error(ZeezLogger.error, "Failed to save respiratory data: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
        healthStore.execute(query)
    }
}
