import CoreData
import HealthKit
import UIKit
import os.log

/// What a recording runs while it is active. Production starts the microphone; tests pass a
/// fake, so starting a session never touches real audio.
protocol SessionMonitoring {
    /// Throws when the recording cannot run: without the microphone it measures nothing.
    func start(for session: SleepSession) throws
    func stop()
}

/// The monitors a recording runs. Their lifecycle belongs here and nowhere else
/// (`SessionMonitorLifecycleGuardTests`). The phone records no movement (decision
/// 2026-11-01, `PARKED_CAPABILITIES.md` §15): it lies on a nightstand, not on the pillow.
struct LiveSessionMonitors: SessionMonitoring {
    func start(for session: SleepSession) throws {
        try EnvironmentalMonitor.shared.startMonitoring(for: session)
    }

    func stop() {
        EnvironmentalMonitor.shared.stopMonitoring()
    }
}

/// Where a recording's heart rate comes from. Production reads Apple Health, which the
/// watch writes to; tests pass a fake.
protocol HeartRateSource {
    func heartRates(from start: Date, to end: Date,
                    completion: @escaping (Result<[(timestamp: Date, value: Double)], Error>) -> Void)
}

struct HealthKitHeartRateSource: HeartRateSource {
    let store: HKHealthStore

    func heartRates(from start: Date, to end: Date,
                    completion: @escaping (Result<[(timestamp: Date, value: Double)], Error>) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.failure(AppError.healthKitNotAvailable))
            return
        }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(.failure(AppError.sensorDataUnavailable))
            return
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            let heartRateData = samples?.compactMap { sample -> (timestamp: Date, value: Double)? in
                guard let sample = sample as? HKQuantitySample else { return nil }
                return (
                    timestamp: sample.startDate,
                    value: sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                )
            } ?? []

            completion(.success(heartRateData))
        }

        store.execute(query)
    }
}

/// How ending a recording turned out.
enum SessionEndOutcome {
    /// Saved; heart-rate sync and analysis follow.
    case saved(SleepSession)
    /// Shorter than `AppConstants.Sleep.minimumSessionDuration`, so deleted rather than kept.
    case discardedTooShort
}

final class SleepSessionManager {
    static let shared = SleepSessionManager()

    private let persistenceController: PersistenceController
    private let healthStore: HKHealthStore
    private let errorManager = ErrorManager.shared
    private let validator: SleepSessionValidator
    private let monitors: SessionMonitoring
    private let heartRateSource: HeartRateSource
    /// Sessions whose heart rate is being synced, so two syncs never insert it twice.
    private let syncLock = NSLock()
    private var syncingSessions: Set<NSManagedObjectID> = []

    /// How long after a recording ends Zeez still looks for its heart rate.
    static let pendingHeartRateWindow: TimeInterval = 36 * 3600

    /// Tests inject an in-memory controller (second audit A7) so the whole
    /// end-of-session flow — validation, save, analysis — stays off the
    /// shared store, fake monitors and a fake heart-rate source; production uses the
    /// shared stack and Apple Health.
    init(persistenceController: PersistenceController = .shared,
         monitors: SessionMonitoring = LiveSessionMonitors(),
         heartRateSource: HeartRateSource? = nil) {
        self.persistenceController = persistenceController
        self.validator = SleepSessionValidator(persistenceController: persistenceController)
        self.healthStore = HKHealthStore()
        self.monitors = monitors
        self.heartRateSource = heartRateSource ?? HealthKitHeartRateSource(store: healthStore)
    }
    
    /// Recording needs no HealthKit: heart rate is synced at the end when HealthKit has any.
    /// It does need its monitors: when they cannot start, the session is deleted again rather
    /// than left running with nothing recording it, and the error goes to the caller.
    func startSession(completion: @escaping (Result<SleepSession, Error>) -> Void) {
        let context = persistenceController.container.viewContext

        // Create new session
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date()
        session.isActive = true
        session.createdAt = Date()
        session.modifiedAt = Date()
        session.deviceIdentifier = UIDevice.current.identifierForVendor?.uuidString
        
        do {
            // Validate the new session
            try validator.validateSession(session)
            
            // Save if validation passes
            try context.save()
        } catch {
            context.rollback()
            errorManager.reportError(error)
            completion(.failure(error))
            return
        }

        do {
            try monitors.start(for: session)
        } catch {
            ZeezLogger.error(ZeezLogger.sleepTracking, "Recording monitors did not start", error: error)
            monitors.stop()
            context.delete(session)
            do {
                try context.save()
            } catch {
                ZeezLogger.error(ZeezLogger.sleepTracking, "Could not remove the recording that did not start", error: error)
            }
            completion(.failure(error))
            return
        }
        completion(.success(session))
    }
    
    /// Ends a recording at `endTime`, capped at `AppConstants.Sleep.maximumSessionDuration`.
    ///
    /// Ending never fails for want of data: one shorter than the minimum is deleted, and the
    /// rest is saved whatever its readings cover. Only a failed save leaves it running.
    func endSession(_ session: SleepSession,
                    at endTime: Date = Date(),
                    completion: @escaping (Result<SessionEndOutcome, Error>) -> Void) {
        let context = persistenceController.container.viewContext

        guard let startTime = session.startTime else {
            completion(.failure(SessionValidationError.missingStartTime))
            return
        }
        let end = min(endTime, startTime.addingTimeInterval(AppConstants.Sleep.maximumSessionDuration))

        guard end.timeIntervalSince(startTime) >= AppConstants.Sleep.minimumSessionDuration else {
            context.delete(session)
            do {
                try context.save()
                monitors.stop()
                ZeezLogger.info(ZeezLogger.sleepTracking, "Recording under the minimum length discarded")
                completion(.success(.discardedTooShort))
            } catch {
                context.rollback()
                errorManager.reportError(error)
                completion(.failure(error))
            }
            return
        }

        session.endTime = end
        session.isActive = false
        session.modifiedAt = Date()

        // qualityScore stays 0 = awaiting analysis. The old hoursSlept×10
        // write here was a fabricated score (claims rule 4) whose nonzero
        // value also excluded the session from the analysis backlog, so
        // Zeez-recorded sessions never earned a real estimate (A7).

        do {
            try validator.validateEnd(session)
            try context.save()
            monitors.stop()
            completion(.success(.saved(session)))

            // Sync heart-rate data from HealthKit, THEN analyze — the
            // estimate must see the imported samples, so analysis is chained
            // onto the sync completion (and still runs if the sync fails:
            // the session may carry movement data on its own).
            let sessionID = session.objectID
            let container = persistenceController.container
            syncWithHealthKit(for: session) { error in
                if let error = error {
                    self.errorManager.reportError(error)
                }
                Task {
                    do {
                        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: sessionID, container: container)
                    } catch {
                        // A session too short or without the inputs gets the sentinel
                        // instead of throwing; this is a failed fetch or save.
                        ZeezLogger.info(ZeezLogger.sleepTracking, "End-of-session analysis skipped: \(error.localizedDescription)")
                    }
                }
            }

        } catch {
            context.rollback()
            errorManager.reportError(error)
            completion(.failure(error))
        }
    }
    
    func requestHealthKitAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HealthKitAuthorization.isAvailable else {
            errorManager.report(.healthKitNotAvailable)
            completion(false, AppError.healthKitNotAvailable)
            return
        }

        HealthKitAuthorization.request(using: healthStore) { success, error in
            if !success {
                self.errorManager.report(.healthKitPermissionDenied)
            }
            completion(success, error)
        }
    }
    
    func activeSession() throws -> SleepSession? {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.fetchLimit = 1
        
        return try context.fetch(request).first
    }
    
    /// Heart rate for recent recordings that ended without any. A recording that ends for the
    /// alarm usually ends with the phone locked, when Apple Health cannot be read, and the
    /// watch may not have synced the night yet. Zeez looks again each time it comes to the
    /// foreground, for recordings ended in the last `pendingHeartRateWindow`. Main thread.
    func syncPendingHeartRate(now: Date = Date(), completion: @escaping () -> Void = {}) {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "isActive == NO AND endTime >= %@ AND heartRateData.@count == 0 AND NOT (deviceIdentifier CONTAINS[c] %@)",
            now.addingTimeInterval(-Self.pendingHeartRateWindow) as NSDate,
            AppConstants.DataProvenance.healthKitMarker
        )
        let sessions = (try? context.fetch(request)) ?? []
        guard !sessions.isEmpty else {
            completion()
            return
        }

        let group = DispatchGroup()
        for session in sessions {
            group.enter()
            syncWithHealthKit(for: session) { error in
                if let error {
                    ZeezLogger.info(ZeezLogger.sleepTracking, "Heart rate not synced yet: \(error.localizedDescription)")
                }
                group.leave()
            }
        }
        group.notify(queue: .main, execute: completion)
    }

    func syncWithHealthKit(for session: SleepSession, completion: @escaping (Error?) -> Void) {
        guard let startTime = session.startTime,
              let endTime = session.endTime else {
            completion(AppError.dataProcessingFailed)
            return
        }

        // The HKSampleQuery result handler runs on a HealthKit background thread —
        // only the objectID crosses into it; inserts happen on a background
        // context's queue (snapshot pattern, second audit A3).
        let sessionID = session.objectID

        // A sync already running for this session will insert its heart rate.
        syncLock.lock()
        let isNew = syncingSessions.insert(sessionID).inserted
        syncLock.unlock()
        guard isNew else {
            completion(nil)
            return
        }
        let finish: (Error?) -> Void = { [weak self] error in
            if let self {
                self.syncLock.lock()
                self.syncingSessions.remove(sessionID)
                self.syncLock.unlock()
            }
            completion(error)
        }

        heartRateSource.heartRates(from: startTime, to: endTime) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let heartRateData):
                let context = self.persistenceController.newBackgroundContext()
                context.perform {
                    do {
                        guard let session = try context.existingObject(with: sessionID) as? SleepSession else {
                            finish(AppError.dataProcessingFailed)
                            return
                        }

                        // Same bucketing as the bulk importer, so a session's stored
                        // heart-rate resolution does not depend on how it was created.
                        let readings = HeartRateDownsampler.downsample(
                            heartRateData.map { HeartRateDownsampler.Sample(timestamp: $0.timestamp, value: $0.value) }
                        )
                        readings.forEach { data in
                            let heartRate = HeartRateData(context: context)
                            heartRate.id = UUID()
                            heartRate.timestamp = data.timestamp
                            heartRate.value = data.value
                            heartRate.deviceType = "Apple Watch"
                            heartRate.session = session
                        }

                        try context.save()
                        finish(nil)
                    } catch {
                        self.errorManager.reportError(AppError.dataProcessingFailed)
                        finish(AppError.dataProcessingFailed)
                    }
                }

            case .failure(let error):
                self.errorManager.reportError(error)
                finish(error)
            }
        }
    }
}
