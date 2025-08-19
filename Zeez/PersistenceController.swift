import CoreData
import os.log

final class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer
    private(set) var isStoreLoaded: Bool = false
    
    private init() {
        container = NSPersistentContainer(name: "Zeez")
        
        // Configure store options
        if let description = container.persistentStoreDescriptions.first {
            // Enable history tracking
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            
            // Migration options
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            
            // SQLite optimizations
            let pragmaOptions: [String: String] = [
                "journal_mode": "DELETE",          // Use simpler journaling
                "synchronous": "NORMAL",           // Reduce write-ahead logging
                "page_size": "4096",              // Optimize page size
                "temp_store": "MEMORY",           // Use memory for temp storage
                "auto_vacuum": "FULL"             // Enable full auto-vacuum
            ]
            description.setOption(pragmaOptions as NSDictionary, forKey: NSSQLitePragmasOption)
        }
        
        container.loadPersistentStores { [weak self] description, error in
            if let error = error {
                ZeezLogger.error(ZeezLogger.coreData, "Core Data failed to load", error: error)
                self?.isStoreLoaded = false
            } else {
                ZeezLogger.info(ZeezLogger.coreData, "Core Data store loaded successfully")
                self?.isStoreLoaded = true
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: - Preview Helper
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Zeez")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        }
        
        container.loadPersistentStores { [weak self] description, error in
            if let error = error {
                ZeezLogger.error(ZeezLogger.coreData, "Core Data failed to load store", error: error)
                self?.isStoreLoaded = false
                
                // For in-memory stores, try to recreate the store
                if inMemory {
                    ZeezLogger.info(ZeezLogger.coreData, "Attempting to recreate in-memory store...")
                    // In-memory stores should generally work, but if they fail,
                    // we can continue with an empty store
                } else {
                    ZeezLogger.error(ZeezLogger.coreData, "Persistent store failed to load. App will continue with limited functionality.")
                    // In production, you might want to:
                    // 1. Try to load with a fallback in-memory store
                    // 2. Notify the user about data access issues
                    // 3. Implement a recovery mechanism
                    
                    // For now, we'll log the error and continue
                    // The app can still function, but data persistence will be limited
                }
            } else {
                ZeezLogger.info(ZeezLogger.coreData, "Core Data store loaded successfully (init)")
                self?.isStoreLoaded = true
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    func clearAllData() {
        guard let url = container.persistentStoreDescriptions.first?.url else { return }
        
        let coordinator = container.persistentStoreCoordinator
        
        // Remove the store first
        if let store = coordinator.persistentStore(for: url) {
            do {
                try coordinator.remove(store)
            } catch {
                ZeezLogger.error(ZeezLogger.coreData, "Failed to remove store", error: error)
                return
            }
        }
        
        // Delete the files
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: url)
        try? fileManager.removeItem(at: url.appendingPathExtension("shm"))
        try? fileManager.removeItem(at: url.appendingPathExtension("wal"))
        try? fileManager.removeItem(at: url.appendingPathExtension("sqlite-journal"))
        
        // Add a new store
        do {
            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: url,
                options: container.persistentStoreDescriptions.first?.options
            )
            ZeezLogger.info(ZeezLogger.coreData, "Successfully cleared and recreated store")
        } catch {
            ZeezLogger.error(ZeezLogger.coreData, "Failed to add new store", error: error)
        }
    }
}
