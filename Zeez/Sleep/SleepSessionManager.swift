import CoreData
import HealthKit
import UIKit
import os.log

final class SleepSessionManager {
    static let shared = SleepSessionManager()

    private let persistenceController: PersistenceController
    private let healthStore: HKHealthStore
    private let errorManager = ErrorManager.shared
    private let validator: SleepSessionValidator

    /// Tests inject an in-memory controller (second audit A7) so the whole
    /// end-of-session flow — validation, save, analysis — stays off the
    /// shared store; production uses the shared stack.
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.validator = SleepSessionValidator(persistenceController: persistenceController)
        self.healthStore = HKHealthStore()
    }
    
    func startSession(completion: @escaping (Result<SleepSession, Error>) -> Void) {
        let context = persistenceController.container.viewContext
        
        guard HKHealthStore.isHealthDataAvailable() else {
            errorManager.showError(.healthKitNotAvailable)
            completion(.failure(AppError.healthKitNotAvailable))
            return
        }
        
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
            errorManager.showStatus("Sleep session started")
            completion(.success(session))
            
            // Start monitoring systems
            EnvironmentalMonitor.shared.startMonitoring(for: session)
            MovementDataManager.shared.startMonitoring(for: session)
            
        } catch {
            context.rollback()
            errorManager.reportError(error)
            completion(.failure(error))
        }
    }
    
    func endSession(_ session: SleepSession, completion: @escaping (Result<SleepSession, Error>) -> Void) {
        let context = persistenceController.container.viewContext
        
        session.endTime = Date()
        session.isActive = false
        session.modifiedAt = Date()

        // qualityScore stays 0 = awaiting analysis. The old hoursSlept×10
        // write here was a fabricated score (claims rule 4) whose nonzero
        // value also excluded the session from the analysis backlog, so
        // Zeez-recorded sessions never earned a real estimate (A7).

        do {
            // Validate session before saving
            try validator.validateSession(session)
            
            // Save if validation passes
            try context.save()
            
            // Stop monitoring systems
            EnvironmentalMonitor.shared.stopMonitoring()
            MovementDataManager.shared.stopMonitoring()
            
            errorManager.showStatus("Sleep session saved")
            completion(.success(session))

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
        guard HKHealthStore.isHealthDataAvailable() else {
            errorManager.showError(.healthKitNotAvailable)
            completion(false, AppError.healthKitNotAvailable)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if !success {
                self.errorManager.showError(.healthKitPermissionDenied)
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
