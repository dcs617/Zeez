import CoreData
import os.log

final class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer
    private(set) var isStoreLoaded: Bool = false

    /// Set when `handleMigrationFallback` had to start a fresh store; RootView shows
    /// a one-time "your history could not be migrated, a backup was kept" notice.
    static let migrationDataLossNoticeKey = "coreDataMigrationFallbackNotice"

    /// Set once the store is opened from the App Group container. Read only to detect an
    /// install that adopted the group and then lost access to it (see `adoptAppGroupStore`).
    static let appGroupAdoptedKey = "coreDataStoreAdoptedAppGroupContainer"

    /// One model instance shared by every container. `NSPersistentContainer(name:)`
    /// loads a fresh NSManagedObjectModel per container; duplicate models
    /// re-register the NSManagedObject subclasses, making `+entity` lookup
    /// ambiguous ("Failed to find a unique match for an NSEntityDescription")
    /// and intermittently failing saves with 134020/133010. Everything that
    /// needs the current model (containers, CoreDataMigrationManager, tests)
    /// must use this instance (2.4).
    static let model: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "Zeez", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Unable to load the Zeez managed object model from the bundle")
        }
        return model
    }()

    private init() {
        container = NSPersistentContainer(name: "Zeez", managedObjectModel: Self.model)
        
        #if DEBUG
        // Enable Core Data debugging (removed private key access)
        container.viewContext.performAndWait {
            // Core Data threading validation is handled automatically by the framework
            ZeezLogger.debug(ZeezLogger.coreData, "Main view context initialized")
        }
        #endif

        // Must precede configureStoreForMigration(), which reads description.url and asks
        // CoreDataMigrationManager about that store — it has to see the final location.
        Self.adoptAppGroupStore(for: container)

        // Configure store options with migration support
        self.configureStoreForMigration()

        container.loadPersistentStores { [weak self] description, error in
            if let error = error {
                ZeezLogger.error(ZeezLogger.coreData, "Core Data failed to load", error: error)
                self?.handleMigrationError(error: error, description: description)
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
        
        #if DEBUG
        // Background context debugging (removed private key access)
        context.performAndWait {
            // Core Data threading validation is handled automatically by the framework
            ZeezLogger.debug(ZeezLogger.coreData, "Background context initialized")
        }
        #endif
        
        return context
    }
    
    // MARK: - Preview Helper
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
    
    /// Non-shared instances are for tests, previews, and deliberately scratch stores
    /// (e.g. `LearnContentLoader`) ONLY — production code must use `.shared`. The
    /// argument has no default value so an accidental `PersistenceController()`
    /// fails to compile instead of silently creating a second stack (2.6).
    init(inMemory: Bool) {
        container = NSPersistentContainer(name: "Zeez", managedObjectModel: Self.model)
        
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
    
    // MARK: - Store Location

    /// Point `container` at the App Group store, relocating an existing app-container
    /// store into it first.
    ///
    /// Widgets and other extensions can only reach the app's Core Data store through a
    /// shared App Group container, so that is where the store lives. Every failure here
    /// leaves the container on its default app-container URL: a store the user can still
    /// read beats a store the widget could have read.
    private static func adoptAppGroupStore(for container: NSPersistentContainer) {
        guard let description = container.persistentStoreDescriptions.first,
              let legacyURL = description.url else { return }

        guard let groupURL = StoreLocation.groupStoreURL() else {
            // Relocation destroys the app-container store, so an install that once reached
            // the group container and no longer can is about to open an empty store where
            // the user's history used to be. That means the app-groups entitlement was
            // dropped from the signature — a build configuration problem, not a data problem.
            if UserDefaults.standard.bool(forKey: Self.appGroupAdoptedKey) {
                ZeezLogger.fault(
                    ZeezLogger.coreData,
                    "App Group container is unreachable but this install previously adopted it. Opening the app-container store, which no longer holds the user's history. Verify the app-groups entitlement is still provisioned."
                )
            } else {
                ZeezLogger.error(
                    ZeezLogger.coreData,
                    "App Group container unavailable — keeping the app-container store. A widget extension will not be able to read it."
                )
            }
            return
        }

        do {
            if try StoreLocation.relocateStore(from: legacyURL, to: groupURL) {
                ZeezLogger.info(ZeezLogger.coreData, "Relocated the Core Data store into the App Group container")
            }
        } catch {
            ZeezLogger.error(
                ZeezLogger.coreData,
                "Store relocation into the App Group container failed — keeping the app-container store",
                error: error
            )
            return
        }

        description.url = groupURL
        UserDefaults.standard.set(true, forKey: Self.appGroupAdoptedKey)
    }

    // MARK: - Migration Support

    private func configureStoreForMigration() {
        guard let description = container.persistentStoreDescriptions.first else { return }
        Self.prepareForLoading(description)
    }

    /// Set `description`'s migration and history options, backing the store up first when
    /// it was written by an older model.
    ///
    /// Automatic lightweight migration stays on even when migration is required. Core Data
    /// migrates in place and handles the WAL itself; it also uses any bundled mapping model,
    /// so a future heavyweight step needs no change here. This used to switch automatic
    /// migration *off* whenever it was needed, which forced every upgrade through the
    /// load-failure → `performManualMigration` path — a path no structural model change had
    /// ever exercised. That path is now only the fallback when automatic migration fails.
    static func prepareForLoading(
        _ description: NSPersistentStoreDescription,
        migrationManager: CoreDataMigrationManager = .shared
    ) {
        if let storeURL = description.url,
           FileManager.default.fileExists(atPath: storeURL.path),
           migrationManager.requiresMigration(from: storeURL) {
            do {
                let backupURL = try migrationManager.backUpStore(at: storeURL)
                ZeezLogger.info(ZeezLogger.coreData, "Migration required - backed up the store to \(backupURL.lastPathComponent), migrating automatically")
            } catch {
                // A failed backup must not block the upgrade: the migration itself does not
                // depend on it, and refusing to open the store would strand the user's data.
                ZeezLogger.error(ZeezLogger.coreData, "Pre-migration backup failed - migrating without one", error: error)
            }
        }

        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        // History tracking must STAY enabled: existing stores were created with it,
        // and Core Data force-opens a previously-tracked store READ-ONLY when the key
        // is later omitted (the "Store opened without NSPersistentHistoryTrackingKey…"
        // warning). Nothing consumes the history, so BackgroundTaskManager prunes it
        // periodically instead (2.6).
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        // No NSSQLitePragmasOption: the old journal_mode=DELETE disabled WAL for no
        // benefit, and auto_vacuum set via pragma after creation is ineffective (2.6).
    }

    /// Delete persistent-history transactions older than `date`. History tracking is
    /// required (see `configureStoreForMigration`) but unconsumed, so unbounded growth
    /// is pruned from BackgroundTaskManager's processing task.
    func purgePersistentHistory(olderThan date: Date, in context: NSManagedObjectContext) {
        let purge = NSPersistentHistoryChangeRequest.deleteHistory(before: date)
        do {
            try context.execute(purge)
            ZeezLogger.debug(ZeezLogger.coreData, "Purged persistent history older than \(date)")
        } catch {
            ZeezLogger.error(ZeezLogger.coreData, "Persistent-history purge failed", error: error)
        }
    }
    
    private func handleMigrationError(error: Error, description: NSPersistentStoreDescription?) {
        guard let storeURL = description?.url else {
            ZeezLogger.error(ZeezLogger.coreData, "No store URL available for migration recovery")
            self.isStoreLoaded = false
            return
        }
        
        // Check if this is a migration-related error
        let nsError = error as NSError
        let migrationErrors = [NSMigrationMissingSourceModelError, NSMigrationMissingMappingModelError, NSMigrationManagerSourceStoreError, 134100] // 134100 = incompatible model version
        
        if migrationErrors.contains(nsError.code) {
            ZeezLogger.info(ZeezLogger.coreData, "Attempting migration recovery due to error: \(nsError.code)")

            // NOTE: an empty NSStoreModelVersionIdentifiers entry does NOT mean the store is
            // foreign/unversioned — every store created by model v1 has an empty identifier
            // (Xcode's default). Always attempt migration first; handleMigrationFallback
            // below still backs up and recreates stores that genuinely cannot be migrated.
            do {
                // Try manual migration
                try performManualMigration(storeURL: storeURL)
                
                // Retry loading the store
                try retryStoreLoad()
                
            } catch {
                ZeezLogger.error(ZeezLogger.coreData, "Manual migration failed", error: error)
                self.handleMigrationFallback(storeURL: storeURL)
            }
        } else {
            ZeezLogger.error(ZeezLogger.coreData, "Non-migration related error", error: error)
            self.isStoreLoaded = false
        }
    }
    
    private func performManualMigration(storeURL: URL) throws {
        let migrationManager = CoreDataMigrationManager.shared
        let tempURL = storeURL.appendingPathExtension("migrated")
        
        // Perform the migration to a temporary location
        try migrationManager.migrateStore(from: storeURL, to: tempURL)

        // Swap the migrated store in. This used to remove and move files by hand, using
        // `appendingPathExtension("wal")` — `Zeez.sqlite.wal`, a name SQLite never writes —
        // so the old store's real `-wal`/`-shm` were left beside the migrated file and the
        // migrated store's own WAL was left behind. `replacePersistentStore` carries the
        // sidecars correctly (see StoreLocation.relocateStore).
        try migrationManager.replaceStore(at: storeURL, withStoreAt: tempURL)

        ZeezLogger.info(ZeezLogger.coreData, "Manual migration completed successfully")
    }
    
    private func retryStoreLoad() throws {
        // Reconfigure store options after migration
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }
        
        // Load the migrated store
        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                loadError = error
                ZeezLogger.error(ZeezLogger.coreData, "Failed to load migrated store", error: error)
                self?.isStoreLoaded = false
            } else {
                ZeezLogger.info(ZeezLogger.coreData, "Successfully loaded migrated store")
                self?.isStoreLoaded = true
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = loadError {
            throw error
        }
    }
    
    private func handleMigrationFallback(storeURL: URL) {
        ZeezLogger.error(ZeezLogger.coreData, "Migration failed - implementing fallback strategy")
        
        // Option 1: Offer data export (placeholder for future implementation)
        // exportUserDataForRecovery()
        
        // Option 2: Rename corrupted store and start fresh
        let corruptedURL = storeURL.appendingPathExtension("corrupted-\(Date().timeIntervalSince1970)")
        
        do {
            try FileManager.default.moveItem(at: storeURL, to: corruptedURL)
            ZeezLogger.info(ZeezLogger.coreData, "Moved corrupted store to backup location: \(corruptedURL.lastPathComponent)")

            // Surface the data loss to the user instead of failing silently —
            // RootView reads this flag and shows a one-time notice (2.6).
            UserDefaults.standard.set(true, forKey: Self.migrationDataLossNoticeKey)

            // Try to load with a fresh store
            try retryStoreLoad()

            // Log the data loss event for analytics
            ZeezLogger.error(ZeezLogger.coreData, "Data migration failed - user data preserved at backup location: \(corruptedURL.lastPathComponent) - data can be recovered")

        } catch {
            ZeezLogger.error(ZeezLogger.coreData, "Failed to implement migration fallback", error: error)
            self.isStoreLoaded = false
        }
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
