import CoreData

final class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer
    
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
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
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
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
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
                print("Failed to remove store: \(error)")
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
            print("Successfully cleared and recreated store")
        } catch {
            print("Failed to add new store: \(error)")
        }
    }
}