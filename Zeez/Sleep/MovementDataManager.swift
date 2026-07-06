import CoreData
import CoreMotion
import UIKit
import os.log

final class MovementDataManager {
    static let shared = MovementDataManager()
    
    private let motionManager = CMMotionManager()
    private let persistenceController: PersistenceController
    private let operationQueue = OperationQueue()
    private let samplingInterval: TimeInterval = 60 // 1 minute
    private let errorManager = ErrorManager.shared
    
    private init() {
        self.persistenceController = .shared
        setupMotionManager()
    }
    
    private func setupMotionManager() {
        motionManager.accelerometerUpdateInterval = samplingInterval
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.qualityOfService = .utility
    }
    
    func startMonitoring(for session: SleepSession) {
        guard motionManager.isAccelerometerAvailable else {
            errorManager.showError(.sensorDataUnavailable)
            return
        }

        // Capture objectID (not the session object) to avoid crossing Core Data context-queue
        // boundaries: Core Motion delivers callbacks on operationQueue, not the view-context queue.
        let sessionID = session.objectID

        motionManager.startAccelerometerUpdates(to: operationQueue) { [weak self] data, error in
            if let error = error {
                self?.errorManager.reportError(error)
                return
            }
            guard let self, let accelerometerData = data else { return }
            self.processAccelerometerData(accelerometerData, sessionID: sessionID)
        }

        errorManager.showStatus("Movement tracking started")
    }
    
    func stopMonitoring() {
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
            errorManager.showStatus("Movement tracking stopped")
        }
    }
    
    private func processAccelerometerData(_ data: CMAccelerometerData, sessionID: NSManagedObjectID) {
        // Use a private background context so writes from the Core Motion operation queue
        // never touch the view context directly.
        let bgContext = persistenceController.container.newBackgroundContext()
        bgContext.perform {
            guard let session = try? bgContext.existingObject(with: sessionID) as? SleepSession else { return }

            let movement = MovementData(context: bgContext)
            movement.id = UUID()
            movement.timestamp = Date()
            movement.deviceType = UIDevice.current.model
            movement.session = session

            movement.xAcceleration = data.acceleration.x
            movement.yAcceleration = data.acceleration.y
            movement.zAcceleration = data.acceleration.z

            let magnitude = sqrt(
                pow(data.acceleration.x, 2) +
                pow(data.acceleration.y, 2) +
                pow(data.acceleration.z, 2)
            )
            movement.magnitude = magnitude
            movement.activityLevel = self.determineActivityLevel(magnitude: magnitude)

            do {
                try bgContext.save()
            } catch {
                self.errorManager.reportError(AppError.dataProcessingFailed)
            }
        }
    }
    
    private func determineActivityLevel(magnitude: Double) -> Int16 {
        switch magnitude {
        case 0..<0.05:  return 0
        case 0.05..<0.1: return 1
        case 0.1..<0.2:  return 2
        case 0.2..<0.3:  return 3
        case 0.3..<0.5:  return 4
        default:         return 5
        }
    }
    
    func getMovementData(for session: SleepSession) throws -> [MovementData] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<MovementData> = MovementData.fetchRequest()
        request.predicate = NSPredicate(format: "session == %@", session)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MovementData.timestamp, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            errorManager.reportError(error)
            throw error
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
