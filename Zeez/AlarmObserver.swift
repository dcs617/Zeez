import Foundation
import CoreData
import Combine
import UIKit

/// Observes changes to alarms and ensures they are properly scheduled
class AlarmObserver: NSObject {
    static let shared = AlarmObserver()
    
    private let scheduler = AlarmScheduler.shared
    private let watchHandler = WatchConnectivityHandler.shared
    private var cancellables = Set<AnyCancellable>()
    
    override private init() {
        super.init()
        setupAppLifecycleObservers()
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
        // Reschedule alarms when app becomes active
        NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification
        )
        .sink { [weak self] _ in
            self?.rescheduleAlarmsIfNeeded()
        }
        .store(in: &cancellables)
        
        // Handle time changes
        NotificationCenter.default.publisher(
            for: UIApplication.significantTimeChangeNotification
        )
        .sink { [weak self] _ in
            self?.rescheduleAlarmsIfNeeded()
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
        
        // Handle changes
        if !insertedAlarms.isEmpty || !updatedAlarms.isEmpty || !deletedAlarms.isEmpty {
            // Reschedule all alarms to ensure consistency
            if let context = (insertedAlarms.first ?? updatedAlarms.first)?.managedObjectContext {
                scheduler.scheduleAllAlarms(context: context)
            }
            
            // Update watch app
            (insertedAlarms.union(updatedAlarms)).forEach { alarm in
                watchHandler.updateAlarmContext(alarm)
            }
        }
    }
    
    private func rescheduleAlarmsIfNeeded() {
        let context = PersistenceController.shared.container.viewContext
        scheduler.scheduleAllAlarms(context: context)
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
