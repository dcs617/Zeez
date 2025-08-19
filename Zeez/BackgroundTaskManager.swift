import BackgroundTasks
import CoreData
import UIKit
import os.log

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private let persistenceController: PersistenceController
    private let errorManager = ErrorManager.shared
    
    private let sleepUpdateTaskId: String
    private let dataProcessTaskId: String
    
    private var tasksRegistered = false
    
    private init() {
        // Initialize task identifiers with dynamic bundle identifier
        if let bundleId = Bundle.main.bundleIdentifier {
            self.sleepUpdateTaskId = "\(bundleId).sleepupdate"
            self.dataProcessTaskId = "\(bundleId).dataprocess"
        } else {
            // Fallback for development/testing scenarios
            self.sleepUpdateTaskId = "com.zeez.app.sleepupdate"
            self.dataProcessTaskId = "com.zeez.app.dataprocess"
        }
        
        self.persistenceController = .shared
        registerBackgroundTasks()
    }
    
    func registerBackgroundTasks() {
        // Prevent double registration
        guard !tasksRegistered else {
            ZeezLogger.debug(ZeezLogger.background, "Background tasks already registered, skipping...")
            return
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: sleepUpdateTaskId,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleSleepUpdate(task: refreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: dataProcessTaskId,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleDataProcessing(task: processingTask)
        }
        
        tasksRegistered = true
        ZeezLogger.info(ZeezLogger.background, "Background tasks registered successfully")
    }
    
    func scheduleSleepUpdate() {
        let request = BGAppRefreshTaskRequest(identifier: sleepUpdateTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: AppConstants.Background.sleepUpdateInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            errorManager.reportError(AppError.backgroundTaskFailed)
        }
    }
    
    func scheduleDataProcessing() {
        let request = BGProcessingTaskRequest(identifier: dataProcessTaskId)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: AppConstants.Background.dataProcessingInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            errorManager.reportError(AppError.backgroundTaskFailed)
        }
    }
    
    private func handleSleepUpdate(task: BGAppRefreshTask) {
        scheduleNextSleepUpdate()
        
        let context = persistenceController.container.newBackgroundContext()
        
        task.expirationHandler = {
            context.performAndWait {
                context.reset()
            }
        }
        
        updateActiveSleepSession(in: context) { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    private func handleDataProcessing(task: BGProcessingTask) {
        scheduleNextDataProcessing()
        
        let context = persistenceController.container.newBackgroundContext()
        
        task.expirationHandler = {
            context.performAndWait {
                context.reset()
            }
        }
        
        processBackloggedData(in: context) { success in
            task.setTaskCompleted(success: success)
        }
    }
    
    private func scheduleNextSleepUpdate() {
        let request = BGAppRefreshTaskRequest(identifier: sleepUpdateTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: AppConstants.Background.sleepUpdateInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            errorManager.reportError(AppError.backgroundTaskFailed)
        }
    }
    
    private func scheduleNextDataProcessing() {
        let request = BGProcessingTaskRequest(identifier: dataProcessTaskId)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: AppConstants.Background.dataProcessingInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            errorManager.reportError(AppError.backgroundTaskFailed)
        }
    }
    
    private func updateActiveSleepSession(
        in context: NSManagedObjectContext,
        completion: @escaping (Bool) -> Void
    ) {
        context.performAndWait {
            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            request.predicate = NSPredicate(format: "isActive == YES")
            
            do {
                guard let session = try context.fetch(request).first else {
                    completion(true)
                    return
                }
                
                // Update environmental data
                EnvironmentalMonitor.shared.startMonitoring(for: session)
                
                // Update movement data
                MovementDataManager.shared.startMonitoring(for: session)
                
                try context.save()
                completion(true)
            } catch {
                errorManager.reportError(error)
                completion(false)
            }
        }
    }
    
    private func processBackloggedData(
        in context: NSManagedObjectContext,
        completion: @escaping (Bool) -> Void
    ) {
        Task {
            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            request.predicate = NSPredicate(format: "qualityScore == 0 AND isActive == NO")
            
            do {
                let sessions = try await context.perform {
                    try context.fetch(request)
                }
                
                for session in sessions {
                    try await SleepAnalyzer.shared.analyzeSleepSession(session)
                }
                
                try await context.perform {
                    try context.save()
                }
                completion(true)
            } catch {
                errorManager.reportError(error)
                completion(false)
            }
        }
    }

    func checkBatteryAndStorage() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        if UIDevice.current.batteryLevel <= AppConstants.Background.criticalBatteryLevel {
            errorManager.showError(.lowBatteryWarning)
        }
        
        let fileManager = FileManager.default
        if let urlForDocumentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let values = try urlForDocumentsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                if let capacity = values.volumeAvailableCapacityForImportantUsage,
                   capacity < AppConstants.Background.minimumStorageBytes { // 100MB
                    errorManager.showError(.storageSpaceLow)
                }
            } catch {
                errorManager.reportError(error)
            }
        }
    }
}
