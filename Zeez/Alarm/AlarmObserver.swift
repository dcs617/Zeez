import Foundation
import CoreData
import Combine
import UIKit
import os.log

/// Observes changes to alarms and ensures they are properly scheduled
class AlarmObserver: NSObject {
    static let shared = AlarmObserver()

    private let scheduler: AlarmScheduler
    private let watchHandler = WatchConnectivityHandler.shared
    private var cancellables = Set<AnyCancellable>()
    private var reschedulingTimer: Timer?

    /// Tests inject a scheduler built on a fake notification center (2.4).
    init(scheduler: AlarmScheduler = .shared) {
        self.scheduler = scheduler
        super.init()
        setupAppLifecycleObservers()
        
        // Subscribe to app termination for cleanup
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    deinit {
        // Clean up resources
        cleanup()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appWillTerminate() {
        cleanup()
    }
    
    /// Clean up all resources
    private func cleanup() {
        reschedulingTimer?.invalidate()
        reschedulingTimer = nil
        cancellables.removeAll()
    }
    
    /// Reset singleton state for testing
    func reset() {
        cleanup()
    }
    
    func startObserving(context: NSManagedObjectContext) {
        // Observe save notifications from CoreData
        NotificationCenter.default.publisher(
            for: .NSManagedObjectContextDidSave,
            object: context
        )
        .sink { [weak self] notification in
            self?.handleContextSave(notification)
        }
        .store(in: &cancellables)
        
        // Initial scheduling of all alarms
        scheduler.scheduleAllAlarms(context: context)
    }
    
    private func setupAppLifecycleObservers() {
        // Only reschedule on significant time changes, not every app activation
        NotificationCenter.default.publisher(
            for: UIApplication.significantTimeChangeNotification
        )
        .sink { [weak self] _ in
            ZeezLogger.info(ZeezLogger.alarm, "Significant time change detected - rescheduling alarms")
            self?.rescheduleAlarmsIfNeeded()
        }
        .store(in: &cancellables)
        
        // Only check when app enters foreground after being backgrounded for a while
        NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification
        )
        .sink { _ in
            // Only reschedule if app was backgrounded for more than 1 hour
            // This prevents excessive rescheduling during normal app usage
            ZeezLogger.debug(ZeezLogger.alarm, "App entering foreground - checking if reschedule needed")
            // For now, disable this to prevent excessive scheduling
            // TODO: Re-enable rescheduleAlarmsIfNeeded() when needed
        }
        .store(in: &cancellables)
    }
    
    private func handleContextSave(_ notification: Notification) {
        // Get relevant alarm changes
        let insertedAlarms = notification.insertedObjects?
            .filter { $0 is AlarmConfiguration } as? Set<AlarmConfiguration> ?? []
        
        let updatedAlarms = notification.updatedObjects?
            .filter { $0 is AlarmConfiguration } as? Set<AlarmConfiguration> ?? []
        
        let deletedAlarms = notification.deletedObjects?
            .filter { $0 is AlarmConfiguration } as? Set<AlarmConfiguration> ?? []
        
        // Debug logging
        if !insertedAlarms.isEmpty {
            ZeezLogger.info(ZeezLogger.alarm, "🆕 \(insertedAlarms.count) alarm(s) inserted")
        }
        if !updatedAlarms.isEmpty {
            ZeezLogger.info(ZeezLogger.alarm, "✏️ \(updatedAlarms.count) alarm(s) updated")
        }
        if !deletedAlarms.isEmpty {
            ZeezLogger.info(ZeezLogger.alarm, "🗑️ \(deletedAlarms.count) alarm(s) deleted")
        }
        
        // Handle different types of changes efficiently
        if !insertedAlarms.isEmpty || !deletedAlarms.isEmpty {
            // New or deleted alarms require full rescheduling
            ZeezLogger.info(ZeezLogger.alarm, "🔄 Alarms added/removed - rescheduling all alarms")
            if let context = (insertedAlarms.first ?? deletedAlarms.first)?.managedObjectContext {
                debouncedReschedule(context: context)
            }
        } else if !updatedAlarms.isEmpty {
            // Updated alarms - reschedule only the changed ones
            ZeezLogger.info(ZeezLogger.alarm, "✏️ Alarms updated - rescheduling only changed alarms")
            for alarm in updatedAlarms {
                scheduler.scheduleSpecificAlarm(alarm)
            }
        }
        
        // Update watch app for any alarm changes
        if !insertedAlarms.isEmpty || !updatedAlarms.isEmpty {
            (insertedAlarms.union(updatedAlarms)).forEach { alarm in
                watchHandler.updateAlarmContext(alarm)
            }
        }
    }
    
    private func rescheduleAlarmsIfNeeded() {
        ZeezLogger.info(ZeezLogger.alarm, "App lifecycle triggered - checking if alarm rescheduling needed")
        
        let context = PersistenceController.shared.container.viewContext
        
        // Only reschedule if there are actually enabled alarms
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == YES")
        
        guard let alarms = try? context.fetch(request), !alarms.isEmpty else {
            ZeezLogger.debug(ZeezLogger.alarm, "No enabled alarms found - skipping reschedule")
            return
        }
        
        ZeezLogger.info(ZeezLogger.alarm, "Found \(alarms.count) enabled alarms - proceeding with reschedule")
        scheduler.scheduleAllAlarms(context: context)
    }
    
    /// Debounce alarm rescheduling to prevent multiple rapid calls
    private func debouncedReschedule(context: NSManagedObjectContext) {
        // Use serial queue to ensure atomic operations
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Cancel any existing timer atomically
            if let existingTimer = self.reschedulingTimer, existingTimer.isValid {
                ZeezLogger.debug(ZeezLogger.alarm, "⏱️ Canceling previous reschedule timer (debouncing)")
                existingTimer.invalidate()
            }
            
            // Schedule a new timer with a longer delay to reduce excessive rescheduling
            self.reschedulingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] timer in
                guard let self = self else { 
                    timer.invalidate()
                    return 
                }
                
                ZeezLogger.info(ZeezLogger.alarm, "🔄 Rescheduling alarms after debounce delay")
                
                // Clear the timer reference since it's completing
                if self.reschedulingTimer === timer {
                    self.reschedulingTimer = nil
                }
                
                // Perform the actual scheduling
                self.scheduler.scheduleAllAlarms(context: context)
                
                // Debug: Show what was scheduled (after a brief delay)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.scheduler.debugScheduledAlarms()
                }
            }
        }
    }
}

// MARK: - Notification Key Extensions
private extension Notification {
    var insertedObjects: Set<NSManagedObject>? {
        userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject>
    }
    
    var updatedObjects: Set<NSManagedObject>? {
        userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject>
    }
    
    var deletedObjects: Set<NSManagedObject>? {
        userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject>
    }
}
