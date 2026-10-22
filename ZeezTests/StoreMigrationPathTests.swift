import CoreData
import Foundation
import Testing
@testable import Zeez

/// The path a store written by an older model takes on first launch of a newer build.
///
/// `PersistenceController.prepareForLoading` decides it; `CoreDataMigrationManager` backs the
/// store up and, if automatic migration fails, swaps a manually migrated copy in. Every copy
/// must carry the WAL, which may hold the newest transactions.
@Suite("Store migration path")
struct StoreMigrationPathTests {

    // MARK: - Fixtures

    private let history: [AnyHashable: Any] = [NSPersistentHistoryTrackingKey: true as NSNumber]

    private func sandbox() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreMigrationPathTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// The current model minus `SleepSession.userFeedback`: a store it writes needs migrating
    /// to the current model. Subclass claims are removed so it cannot make `+entity` lookup
    /// ambiguous for suites running in parallel (2.4).
    private static let olderModel: NSManagedObjectModel = {
        let model = PersistenceController.model.copy() as! NSManagedObjectModel
        model.entities.forEach { $0.managedObjectClassName = "NSManagedObject" }
        let session = model.entitiesByName["SleepSession"]!
        session.properties.removeAll { $0.name == "userFeedback" }
        return model
    }()

    /// Seed `sessionCount` sessions at `url` with `model`. When `leaveOpen` is true the
    /// coordinator is returned still holding the store, so its rows are only in the WAL.
    @discardableResult
    private func seedStore(at url: URL, model: NSManagedObjectModel, sessionCount: Int,
                           leaveOpen: Bool = false) throws -> NSPersistentStoreCoordinator {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                                       at: url, options: history)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for index in 0..<sessionCount {
                let session = NSEntityDescription.insertNewObject(forEntityName: "SleepSession", into: context)
                session.setValue(UUID(), forKey: "id")
                session.setValue(Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 86_400),
                                 forKey: "startTime")
            }
            try context.save()
        }
        if !leaveOpen { try coordinator.remove(store) }
        return coordinator
    }

    private func sessionCount(in url: URL) throws -> Int {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: PersistenceController.model)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                                       at: url, options: history)
        defer { try? coordinator.remove(store) }
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return try context.performAndWait {
            try context.count(for: NSFetchRequest<NSManagedObject>(entityName: "SleepSession"))
        }
    }

    // MARK: - Backup

    @Test("The pre-migration backup carries rows that exist only in the WAL")
    func backupCarriesUncheckpointedWAL() throws {
        let directory = try sandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Zeez.sqlite")

        let openCoordinator = try seedStore(at: storeURL, model: PersistenceController.model,
                                            sessionCount: 4, leaveOpen: true)
        let backupURL = try CoreDataMigrationManager.shared.backUpStore(at: storeURL)
        openCoordinator.persistentStores.forEach { try? openCoordinator.remove($0) }

        #expect(try sessionCount(in: backupURL) == 4,
                "A backup without the WAL would lose every transaction not yet checkpointed")
    }

    // MARK: - Manual fallback swap

    @Test("Replacing a store installs the replacement's rows and removes its files")
    func replaceStoreInstallsReplacementAndRemovesIt() throws {
        let directory = try sandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Zeez.sqlite")
        let migratedURL = storeURL.appendingPathExtension("migrated")
        try seedStore(at: storeURL, model: PersistenceController.model, sessionCount: 1)
        try seedStore(at: migratedURL, model: PersistenceController.model, sessionCount: 3)

        try CoreDataMigrationManager.shared.replaceStore(at: storeURL, withStoreAt: migratedURL)

        #expect(try sessionCount(in: storeURL) == 3)
        for suffix in ["", "-wal", "-shm"] {
            #expect(!FileManager.default.fileExists(atPath: migratedURL.path + suffix),
                    "Leftover \(migratedURL.lastPathComponent + suffix)")
        }
    }

    // MARK: - Load options

    @Test("A store that needs migrating keeps automatic migration on and is backed up first")
    func storeNeedingMigrationMigratesAutomatically() throws {
        let directory = try sandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Zeez.sqlite")
        try seedStore(at: storeURL, model: Self.olderModel, sessionCount: 2)
        #expect(CoreDataMigrationManager.shared.requiresMigration(from: storeURL))

        let description = NSPersistentStoreDescription(url: storeURL)
        PersistenceController.prepareForLoading(description)

        #expect(description.options[NSMigratePersistentStoresAutomaticallyOption] as? Bool == true,
                "Switching automatic migration off forces every upgrade through the manual fallback")
        #expect(description.options[NSInferMappingModelAutomaticallyOption] as? Bool == true)
        #expect(description.options[NSPersistentHistoryTrackingKey] as? Bool == true)

        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("Zeez.sqlite.migration-backup-") && !$0.hasSuffix("-wal") && !$0.hasSuffix("-shm") }
        #expect(backups.count == 1)
    }

    @Test("A current store is opened as-is, without a backup")
    func currentStoreIsNotBackedUp() throws {
        let directory = try sandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Zeez.sqlite")
        try seedStore(at: storeURL, model: PersistenceController.model, sessionCount: 1)

        let description = NSPersistentStoreDescription(url: storeURL)
        PersistenceController.prepareForLoading(description)

        #expect(description.options[NSMigratePersistentStoresAutomaticallyOption] as? Bool == true)
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.contains("migration-backup") }
        #expect(backups.isEmpty)
    }
}
