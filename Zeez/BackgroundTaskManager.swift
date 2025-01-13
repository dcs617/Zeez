import BackgroundTasks
import CoreData
import UIKit

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private let persistenceController: PersistenceController
    private let errorManager = ErrorManager.shared
    
    private let sleepUpdateTaskId = "com.yourcompany.zeez.sleepupdate"
    private let dataProcessTaskId = "com.yourcompany.zeez.dataprocess"
    
    private init() {
        self.persistenceController = .shared
        registerBackgroundTasks()
    }
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: sleepUpdateTaskId,
            using: nil
        ) { task in
            self.handleSleepUpdate(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: dataProcessTaskId,
            using: nil
        ) { task in
            self.handleDataProcessing(task: task as! BGProcessingTask)
        }
    }
    
    func scheduleSleepUpdate() {
        let request = BGAppRefreshTaskRequest(identifier: sleepUpdateTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
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
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        
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
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
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
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        
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
        
        if UIDevice.current.batteryLevel <= 0.2 {
            errorManager.showError(.lowBatteryWarning)
        }
        
        let fileManager = FileManager.default
        if let urlForDocumentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            do {
                let values = try urlForDocumentsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                if let capacity = values.volumeAvailableCapacityForImportantUsage,
                   capacity < 100_000_000 { // 100MB
                    errorManager.showError(.storageSpaceLow)
                }
            } catch {
                errorManager.reportError(error)
            }
        }
    }
}
