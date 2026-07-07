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
    
    // Enhanced registration tracking
    private var registrationState: RegistrationState = .notRegistered
    private let registrationQueue = DispatchQueue(label: "com.zeez.backgroundRegistration")
    private var registrationAttempts = 0
    private let maxRegistrationAttempts = 3
    
    // Context lifecycle management
    private var backgroundContexts = Set<WeakContextReference>()
    private let contextQueue = DispatchQueue(label: "com.zeez.backgroundContexts", attributes: .concurrent)
    
    // Resource monitoring
    private var resourceMonitor: ResourceMonitor?
    private var userPatternAnalyzer: UserPatternAnalyzer?
    
    // Task success tracking
    private var taskMetrics = TaskMetrics()
    
    private enum RegistrationState {
        case notRegistered
        case registering
        case registered
        case failed(Error)
        
        static func == (lhs: RegistrationState, rhs: RegistrationState) -> Bool {
            switch (lhs, rhs) {
            case (.notRegistered, .notRegistered),
                 (.registering, .registering),
                 (.registered, .registered):
                return true
            case (.failed, .failed):
                return true // Compare error types if needed
            default:
                return false
            }
        }
    }
    
    private func isRegistered() -> Bool {
        if case .registered = registrationState {
            return true
        }
        return false
    }
    
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
        self.resourceMonitor = ResourceMonitor()
        self.userPatternAnalyzer = UserPatternAnalyzer()
        
        // Register tasks during app launch
        registerBackgroundTasksWithRetry()
    }
    
    // MARK: - Enhanced Registration
    
    func registerBackgroundTasksWithRetry() {
        registrationQueue.async { [weak self] in
            self?.performRegistration()
        }
    }
    
    private func performRegistration() {
        guard !isRegistered() else {
            ZeezLogger.info(ZeezLogger.background, "Background tasks already registered")
            return
        }
        
        registrationState = .registering
        registrationAttempts += 1
        
        ZeezLogger.info(ZeezLogger.background, "Attempting background task registration (attempt \(registrationAttempts)/\(maxRegistrationAttempts))")
        
        var sleepUpdateRegistered = false
        var dataProcessRegistered = false
        
        // Register sleep update task
        let sleepUpdateSuccess = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: sleepUpdateTaskId,
            using: DispatchQueue.global(qos: .background)
        ) { [weak self] task in
            guard let self = self,
                  let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleSleepUpdate(task: refreshTask)
        }
        
        sleepUpdateRegistered = sleepUpdateSuccess
        
        // Register data processing task
        let dataProcessSuccess = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: dataProcessTaskId,
            using: DispatchQueue.global(qos: .background)
        ) { [weak self] task in
            guard let self = self,
                  let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleDataProcessing(task: processingTask)
        }
        
        dataProcessRegistered = dataProcessSuccess
        
        if sleepUpdateRegistered && dataProcessRegistered {
            registrationState = .registered
            ZeezLogger.info(ZeezLogger.background, "All background tasks registered successfully")
            
            // Schedule initial tasks
            scheduleSleepUpdate()
            scheduleDataProcessing()
            
        } else {
            let error = BackgroundTaskError.registrationFailed(
                sleepUpdate: sleepUpdateRegistered,
                dataProcess: dataProcessRegistered
            )
            registrationState = .failed(error)
            
            ZeezLogger.error(ZeezLogger.background, "Background task registration failed", error: error)
            
            // Retry if we haven't exceeded max attempts
            if registrationAttempts < maxRegistrationAttempts {
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
                    self?.performRegistration()
                }
            }
        }
    }
    
    // MARK: - Legacy API (for backward compatibility)
    
    func registerBackgroundTasks() {
        // Delegate to new implementation
        registerBackgroundTasksWithRetry()
    }
    
    // MARK: - Intelligent Scheduling
    
    func scheduleSleepUpdate() {
        guard case .registered = registrationState else {
            ZeezLogger.error(ZeezLogger.background, "Cannot schedule tasks - registration not complete")
            return
        }
        
        let request = BGAppRefreshTaskRequest(identifier: sleepUpdateTaskId)
        
        // Use user pattern analysis to determine optimal timing
        if let optimalTime = userPatternAnalyzer?.getOptimalSleepUpdateTime() {
            request.earliestBeginDate = optimalTime
            ZeezLogger.info(ZeezLogger.background, "Sleep update scheduled for optimal time: \(optimalTime)")
        } else {
            // Fallback to standard interval
            request.earliestBeginDate = Date(timeIntervalSinceNow: AppConstants.Background.sleepUpdateInterval)
        }
        
        submitTaskRequest(request)
    }
    
    func scheduleDataProcessing() {
        guard case .registered = registrationState else {
            ZeezLogger.error(ZeezLogger.background, "Cannot schedule tasks - registration not complete")
            return
        }
        
        let request = BGProcessingTaskRequest(identifier: dataProcessTaskId)
        
        // Resource-aware scheduling
        if let resourceStatus = resourceMonitor?.getCurrentResourceStatus() {
            request.requiresExternalPower = resourceStatus.batteryLevel < 0.3
            request.requiresNetworkConnectivity = false
            
            if resourceStatus.thermalState == .critical {
                // Delay processing during thermal stress
                request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 1 hour
            } else {
                request.earliestBeginDate = Date(timeIntervalSinceNow: AppConstants.Background.dataProcessingInterval)
            }
        } else {
            // Conservative defaults
            request.requiresExternalPower = false
            request.requiresNetworkConnectivity = false
            request.earliestBeginDate = Date(timeIntervalSinceNow: AppConstants.Background.dataProcessingInterval)
        }
        
        submitTaskRequest(request)
    }
    
    private func submitTaskRequest(_ request: BGTaskRequest) {
        do {
            try BGTaskScheduler.shared.submit(request)
            taskMetrics.recordScheduleSuccess(for: request.identifier)
        } catch {
            taskMetrics.recordScheduleFailure(for: request.identifier, error: error)
            
            // Enhanced error handling based on error type
            if let bgError = error as? BGTaskScheduler.Error {
                handleSchedulingError(bgError, for: request.identifier)
            } else {
                errorManager.reportError(AppError.backgroundTaskFailed)
            }
        }
    }
    
    private func handleSchedulingError(_ error: BGTaskScheduler.Error, for taskId: String) {
        switch error.code {
        case .unavailable:
            ZeezLogger.error(ZeezLogger.background, "Background refresh is disabled for task: \(taskId)")
            
        case .tooManyPendingTaskRequests:
            ZeezLogger.error(ZeezLogger.background, "Too many pending requests for task: \(taskId)")
            // Cancel existing requests and retry
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskId)
            
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(30)) { [weak self] in
                if taskId == self?.sleepUpdateTaskId {
                    self?.scheduleSleepUpdate()
                } else if taskId == self?.dataProcessTaskId {
                    self?.scheduleDataProcessing()
                }
            }
            
        case .notPermitted:
            ZeezLogger.error(ZeezLogger.background, "Background tasks not permitted for task: \(taskId)")

        // .immediateRunIneligible only exists in the Xcode 26 SDK; CI builds with
        // Xcode 16.x, where it falls into @unknown default. Only reachable via the
        // submit-for-immediate-run API, which Zeez doesn't use.
        #if compiler(>=6.2)
        case .immediateRunIneligible:
            ZeezLogger.error(ZeezLogger.background, "Task ineligible for immediate run: \(taskId)")
        #endif

        @unknown default:
            ZeezLogger.error(ZeezLogger.background, "Unknown scheduling error for task: \(taskId)", error: error)
        }
    }
    
    // MARK: - Enhanced Task Execution
    
    private func handleSleepUpdate(task: BGAppRefreshTask) {
        let startTime = CFAbsoluteTimeGetCurrent()
        ZeezLogger.info(ZeezLogger.background, "Starting sleep update background task")
        
        // Schedule next task immediately
        scheduleSleepUpdate()
        
        let context = createManagedBackgroundContext()
        
        // Enhanced expiration handling
        task.expirationHandler = { [weak self] in
            ZeezLogger.info(ZeezLogger.background, "Sleep update task expiring - cleaning up")
            self?.cleanupBackgroundContext(context)
            self?.taskMetrics.recordTaskExpired(for: task.identifier)
        }
        
        updateActiveSleepSession(in: context) { [weak self] success in
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            if success {
                self?.taskMetrics.recordTaskSuccess(for: task.identifier, duration: duration)
                ZeezLogger.performance(ZeezLogger.background, operation: "Sleep Update Task", duration: duration)
            } else {
                self?.taskMetrics.recordTaskFailure(for: task.identifier)
            }
            
            self?.cleanupBackgroundContext(context)
            task.setTaskCompleted(success: success)
        }
    }
    
    private func handleDataProcessing(task: BGProcessingTask) {
        let startTime = CFAbsoluteTimeGetCurrent()
        ZeezLogger.info(ZeezLogger.background, "Starting data processing background task")
        
        // Check resource constraints
        guard let resourceStatus = resourceMonitor?.getCurrentResourceStatus(),
              resourceStatus.canProcessData else {
            ZeezLogger.info(ZeezLogger.background, "Skipping data processing due to resource constraints")
            task.setTaskCompleted(success: true)
            return
        }
        
        // Schedule next task
        scheduleDataProcessing()
        
        let context = createManagedBackgroundContext()

        // Enhanced expiration handling with progress tracking
        var isProcessingComplete = false
        task.expirationHandler = { [weak self] in
            ZeezLogger.info(ZeezLogger.background, "Data processing task expiring")
            if !isProcessingComplete {
                self?.taskMetrics.recordTaskExpired(for: task.identifier)
            }
            self?.cleanupBackgroundContext(context)
        }

        // Storage maintenance first — serialized ahead of the backlog work on the
        // same context queue, and cheap enough to never threaten the task budget.
        context.perform { [weak self] in
            self?.performStorageMaintenance(in: context)
        }

        processBackloggedData(in: context) { [weak self] success in
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            isProcessingComplete = true
            
            if success {
                self?.taskMetrics.recordTaskSuccess(for: task.identifier, duration: duration)
                ZeezLogger.performance(ZeezLogger.background, operation: "Data Processing Task", duration: duration)
            } else {
                self?.taskMetrics.recordTaskFailure(for: task.identifier)
            }
            
            self?.cleanupBackgroundContext(context)
            task.setTaskCompleted(success: success)
        }
    }
    
    // MARK: - Storage Maintenance (2.6)

    /// Prunes unbounded local storage: unconsumed persistent history and the
    /// local-only analytics entities. Must be called on `context`'s queue.
    private func performStorageMaintenance(in context: NSManagedObjectContext) {
        persistenceController.purgePersistentHistory(
            olderThan: Date().addingTimeInterval(-AppConstants.Background.persistentHistoryRetention),
            in: context
        )

        let cutoff = Date().addingTimeInterval(-AppConstants.Background.analyticsRetention) as NSDate
        for entityName in ["AnalyticsEvent", "FeatureAccessRecord"] {
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetch.predicate = NSPredicate(format: "timestamp < %@", cutoff)
            do {
                let delete = NSBatchDeleteRequest(fetchRequest: fetch)
                try context.execute(delete)
                ZeezLogger.debug(ZeezLogger.background, "Pruned \(entityName) rows older than 90 days")
            } catch {
                ZeezLogger.error(ZeezLogger.background, "Retention prune failed for \(entityName)", error: error)
            }
        }
    }

    // MARK: - Enhanced Context Management

    private func createManagedBackgroundContext() -> NSManagedObjectContext {
        let context = persistenceController.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Track context for cleanup
        contextQueue.async(flags: .barrier) { [weak self] in
            self?.backgroundContexts.insert(WeakContextReference(context: context))
        }
        
        return context
    }
    
    private func cleanupBackgroundContext(_ context: NSManagedObjectContext) {
        context.performAndWait {
            context.reset()
        }
        
        // Remove from tracking
        contextQueue.async(flags: .barrier) { [weak self] in
            self?.backgroundContexts = self?.backgroundContexts.filter { $0.context != nil } ?? Set()
        }
    }
    
    // MARK: - Enhanced Processing
    
    private func updateActiveSleepSession(
        in context: NSManagedObjectContext,
        completion: @escaping (Bool) -> Void
    ) {
        context.perform { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            
            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            request.predicate = NSPredicate(format: "isActive == YES")
            request.fetchLimit = 1
            
            do {
                let sessions = try context.fetch(request)
                guard let session = sessions.first else {
                    // No active session - this is normal
                    completion(true)
                    return
                }
                
                // Check if we should continue monitoring based on resource constraints
                guard let resourceStatus = self.resourceMonitor?.getCurrentResourceStatus(),
                      resourceStatus.canContinueMonitoring else {
                    ZeezLogger.info(ZeezLogger.background, "Pausing monitoring due to resource constraints")
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
                ZeezLogger.error(ZeezLogger.background, "Failed to update active sleep session", error: error)
                completion(false)
            }
        }
    }
    
    private func processBackloggedData(
        in context: NSManagedObjectContext,
        completion: @escaping (Bool) -> Void
    ) {
        Task { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            
            do {
                // Fetch only objectIDs, and build the request inside the context's perform
                // block, to avoid passing managed objects or the (non-Sendable) fetch
                // request across queue boundaries.
                let sessionIDs = try await context.perform {
                    // Get sessions needing analysis with priority ordering.
                    // Exclude HealthKit-imported sessions that already have source-reported stages:
                    // those sessions keep qualityScore=0 (unavailable) intentionally and must not
                    // be routed through stage inference.
                    let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
                    request.predicate = NSPredicate(
                        format: "qualityScore == 0 AND isActive == NO AND NOT (deviceIdentifier CONTAINS[c] %@ AND sleepStages.@count > 0)",
                        AppConstants.DataProvenance.healthKitMarker
                    )
                    request.sortDescriptors = [
                        NSSortDescriptor(key: "endTime", ascending: false) // Most recent first
                    ]
                    return try context.fetch(request).map { $0.objectID }
                }

                // Process in batches with progress monitoring
                let batchSize = self.getBatchSize()
                let idBatches = sessionIDs.chunked(into: batchSize)
                var processedCount = 0

                for batch in idBatches {
                    guard let resourceStatus = self.resourceMonitor?.getCurrentResourceStatus(),
                          resourceStatus.canProcessData else {
                        ZeezLogger.info(ZeezLogger.background, "Stopping processing due to resource constraints after \(processedCount) sessions")
                        break
                    }

                    // SleepAnalyzer accepts an NSManagedObjectID and creates its own
                    // background context, maintaining proper queue confinement.
                    for objectID in batch {
                        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: objectID)
                        processedCount += 1
                    }

                    ZeezLogger.debug(ZeezLogger.background, "Processed \(processedCount)/\(sessionIDs.count) sessions")
                }
                
                ZeezLogger.info(ZeezLogger.background, "Background processing completed: \(processedCount) sessions processed")
                completion(true)
                
            } catch {
                ZeezLogger.error(ZeezLogger.background, "Failed to process backlogged data", error: error)
                completion(false)
            }
        }
    }
    
    private func getBatchSize() -> Int {
        guard let resourceStatus = resourceMonitor?.getCurrentResourceStatus() else {
            return 5 // Conservative default
        }
        
        if resourceStatus.batteryLevel > 0.5 && resourceStatus.thermalState == .nominal {
            return 10 // Higher throughput when resources are good
        } else if resourceStatus.batteryLevel > 0.2 {
            return 5 // Moderate throughput
        } else {
            return 2 // Conservative throughput when battery is low
        }
    }
    
    // MARK: - Resource Monitoring
    
    func checkBatteryAndStorage() {
        guard let resourceMonitor = resourceMonitor else { return }
        
        let status = resourceMonitor.getCurrentResourceStatus()
        
        if status.batteryLevel <= AppConstants.Background.criticalBatteryLevel {
            errorManager.showError(.lowBatteryWarning)
        }
        
        if status.availableStorage < UInt64(AppConstants.Background.minimumStorageBytes) {
            errorManager.showError(.storageSpaceLow)
        }
    }
    
    // MARK: - Public Interface
    
    func getTaskMetrics() -> TaskMetrics {
        return taskMetrics
    }
    
    func getRegistrationStatus() -> String {
        switch registrationState {
        case .notRegistered:
            return "Not Registered"
        case .registering:
            return "Registering"
        case .registered:
            return "Registered"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
    
    func reset() {
        // Clean up all background contexts
        contextQueue.sync {
            for contextRef in backgroundContexts {
                contextRef.context?.reset()
            }
            backgroundContexts.removeAll()
        }
        
        // Reset state for testing
        registrationState = .notRegistered
        registrationAttempts = 0
    }
    
    deinit {
        // Clean up all background contexts
        contextQueue.sync {
            for contextRef in backgroundContexts {
                contextRef.context?.reset()
            }
            backgroundContexts.removeAll()
        }
    }
}

// MARK: - Supporting Types

enum BackgroundTaskError: Error, LocalizedError {
    case registrationFailed(sleepUpdate: Bool, dataProcess: Bool)
    case resourceConstraints
    
    var errorDescription: String? {
        switch self {
        case .registrationFailed(let sleepUpdate, let dataProcess):
            return "Background task registration failed - Sleep Update: \(sleepUpdate), Data Process: \(dataProcess)"
        case .resourceConstraints:
            return "Background task cancelled due to resource constraints"
        }
    }
}

struct TaskMetrics {
    private var scheduleSuccessCount: [String: Int] = [:]
    private var scheduleFailureCount: [String: Int] = [:]
    private var taskSuccessCount: [String: Int] = [:]
    private var taskFailureCount: [String: Int] = [:]
    private var taskExpiredCount: [String: Int] = [:]
    private var averageDuration: [String: Double] = [:]
    
    mutating func recordScheduleSuccess(for taskId: String) {
        scheduleSuccessCount[taskId, default: 0] += 1
    }
    
    mutating func recordScheduleFailure(for taskId: String, error: Error) {
        scheduleFailureCount[taskId, default: 0] += 1
    }
    
    mutating func recordTaskSuccess(for taskId: String, duration: TimeInterval) {
        taskSuccessCount[taskId, default: 0] += 1
        
        let currentAvg = averageDuration[taskId, default: 0.0]
        let count = taskSuccessCount[taskId, default: 1]
        averageDuration[taskId] = (currentAvg * Double(count - 1) + duration) / Double(count)
    }
    
    mutating func recordTaskFailure(for taskId: String) {
        taskFailureCount[taskId, default: 0] += 1
    }
    
    mutating func recordTaskExpired(for taskId: String) {
        taskExpiredCount[taskId, default: 0] += 1
    }
    
    func getSuccessRate(for taskId: String) -> Double {
        let successes = taskSuccessCount[taskId, default: 0]
        let failures = taskFailureCount[taskId, default: 0]
        let total = successes + failures
        
        return total > 0 ? Double(successes) / Double(total) : 0.0
    }
}

class WeakContextReference: Hashable {
    weak var context: NSManagedObjectContext?
    private let identifier: ObjectIdentifier
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.identifier = ObjectIdentifier(context)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    
    static func == (lhs: WeakContextReference, rhs: WeakContextReference) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}