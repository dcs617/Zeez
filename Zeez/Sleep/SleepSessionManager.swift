import CoreData
import HealthKit
import UIKit
import os.log

/// What a recording runs while it is active. Production starts the microphone and motion
/// monitors; tests pass a fake, so starting a session never touches real audio or Core Motion.
protocol SessionMonitoring {
    /// Throws when the recording cannot run: without the microphone it measures nothing.
    func start(for session: SleepSession) throws
    func stop()
}

/// The monitors a recording runs. Their lifecycle belongs here and nowhere else
/// (`SessionMonitorLifecycleGuardTests`).
struct LiveSessionMonitors: SessionMonitoring {
    func start(for session: SleepSession) throws {
        try EnvironmentalMonitor.shared.startMonitoring(for: session)
        MovementDataManager.shared.startMonitoring(for: session)
    }

    func stop() {
        EnvironmentalMonitor.shared.stopMonitoring()
        MovementDataManager.shared.stopMonitoring()
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

    /// Tests inject an in-memory controller (second audit A7) so the whole
    /// end-of-session flow — validation, save, analysis — stays off the
    /// shared store, and fake monitors; production uses the shared stack.
    init(persistenceController: PersistenceController = .shared,
         monitors: SessionMonitoring = LiveSessionMonitors()) {
        self.persistenceController = persistenceController
        self.validator = SleepSessionValidator(persistenceController: persistenceController)
        self.healthStore = HKHealthStore()
        self.monitors = monitors
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
                        // Expected for e.g. sub-30-minute or sensor-less
                        // sessions; the score simply stays unavailable.
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
    
    func syncWithHealthKit(for session: SleepSession, completion: @escaping (Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(AppError.healthKitNotAvailable)
            return
        }
        guard let startTime = session.startTime,
              let endTime = session.endTime else {
            completion(AppError.dataProcessingFailed)
            return
        }

        // The HKSampleQuery result handler runs on a HealthKit background thread —
        // only the objectID crosses into it; inserts happen on a background
        // context's queue (snapshot pattern, second audit A3).
        let sessionID = session.objectID

        fetchHeartRateData(startTime: startTime, endTime: endTime) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let heartRateData):
                let context = self.persistenceController.newBackgroundContext()
                context.perform {
                    do {
                        guard let session = try context.existingObject(with: sessionID) as? SleepSession else {
                            completion(AppError.dataProcessingFailed)
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
                        completion(nil)
                    } catch {
                        self.errorManager.reportError(AppError.dataProcessingFailed)
                        completion(AppError.dataProcessingFailed)
                    }
                }

            case .failure(let error):
                self.errorManager.reportError(error)
                completion(error)
            }
        }
    }
    
    private func fetchHeartRateData(
        startTime: Date,
        endTime: Date,
        completion: @escaping (Result<[(timestamp: Date, value: Double)], Error>) -> Void
    ) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            completion(.failure(AppError.sensorDataUnavailable))
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startTime,
            end: endTime,
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
        
        healthStore.execute(query)
    }
}
