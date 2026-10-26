import Testing
import CoreData
@testable import Zeez

/// Regression tests for the v1 → v2 model hop (roadmap item 1.3).
///
/// v2 fixes the transposed smart-wake defaults (`smartWakeEnabled` "30" → NO,
/// `smartWakeWindow` 9 → 30). Default-value changes do not alter Core Data's
/// entity version hashes, so a v1 store is directly compatible with the v2
/// model: it opens with no migration, existing rows keep their stored values,
/// and only newly inserted rows pick up the corrected defaults. These tests
/// pin that compatibility, the new-row defaults, and (for the day a structural
/// change does require it) that `CoreDataMigrationManager.migrateStore`
/// carries alarm data across intact.
@Suite("Model v1→v2 migration", .serialized)
struct CoreDataModelV2MigrationTests {

    // MARK: - Model loading helpers

    private func momdURL() throws -> URL {
        let url = try #require(Bundle.main.url(forResource: "Zeez", withExtension: "momd"))
        return url
    }

    private func currentModel() throws -> NSManagedObjectModel {
        // The app-wide shared instance — loading another copy of the current
        // model makes subclass→entity resolution ambiguous process-wide (2.4).
        PersistenceController.model
    }

    /// The compiled v1 model ("Zeez.xcdatamodel" → "Zeez.mom" inside the momd),
    /// loaded once and with its NSManagedObject-subclass claims removed: the v1
    /// fixtures only ever use `insertNewObject(forEntityName:)` + KVC, and a
    /// second model claiming `AlarmConfiguration` et al. would make `+entity`
    /// ambiguous for every other suite running in parallel (2.4).
    private static let neutralizedV1Model: NSManagedObjectModel? = {
        guard let momd = Bundle.main.url(forResource: "Zeez", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: momd.appendingPathComponent("Zeez.mom")) else {
            return nil
        }
        model.entities.forEach { $0.managedObjectClassName = "NSManagedObject" }
        return model
    }()

    private func v1Model() throws -> NSManagedObjectModel {
        try #require(Self.neutralizedV1Model)
    }

    /// The compiled v2 model ("Zeez 2.mom"), neutralized the same way. These tests pin the
    /// v1 ↔ v2 relationship specifically; since v3 the *current* model is no longer v2.
    private static let neutralizedV2Model: NSManagedObjectModel? = {
        guard let momd = Bundle.main.url(forResource: "Zeez", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: momd.appendingPathComponent("Zeez 2.mom")) else {
            return nil
        }
        model.entities.forEach { $0.managedObjectClassName = "NSManagedObject" }
        return model
    }()

    private func v2Model() throws -> NSManagedObjectModel {
        try #require(Self.neutralizedV2Model)
    }

    // MARK: - Store helpers

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("v2migration-\(UUID().uuidString).sqlite")
    }

    private func destroyStore(at url: URL, model: NSManagedObjectModel) {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try? coordinator.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }

    /// Creates a SQLite store using the **v1** model containing one alarm, then
    /// tears the coordinator down so the files can be reopened independently.
    private func makeV1Store(alarmID: UUID) throws -> URL {
        let storeURL = temporaryStoreURL()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try v1Model())
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        try context.performAndWait {
            let alarm = NSEntityDescription.insertNewObject(
                forEntityName: "AlarmConfiguration", into: context
            )
            alarm.setValue(alarmID, forKey: "id")
            alarm.setValue("Migration fixture", forKey: "name")
            alarm.setValue(Date(timeIntervalSince1970: 1_750_000_000), forKey: "time")
            alarm.setValue(true, forKey: "enabled")
            // Explicit user values must survive the hop even though defaults changed.
            alarm.setValue(true, forKey: "smartWakeEnabled")
            alarm.setValue(Int16(15), forKey: "smartWakeWindow")
            try context.save()
        }

        try coordinator.remove(store)
        return storeURL
    }

    // MARK: - Tests

    @Test func v1StoreIsDirectlyCompatibleWithV2Model() throws {
        // Default-value changes are not part of the version hash, so a v1 store is
        // directly compatible with v2. (Since v3 it does need migrating to the current
        // model — see CoreDataModelV3MigrationTests.)
        let storeURL = try makeV1Store(alarmID: UUID())
        defer { destroyStore(at: storeURL, model: (try? currentModel()) ?? NSManagedObjectModel()) }

        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: storeURL, options: nil
        )
        #expect(try v2Model().isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata))
    }

    @Test func v1StoreOpensUnderV2ModelWithDataIntact() throws {
        // The actual upgrade-in-place path: a store written by a v1 build opens
        // under the v2 model with migration disabled, and the alarm keeps its
        // explicitly stored (pre-fix) smart-wake values.
        let alarmID = UUID()
        let storeURL = try makeV1Store(alarmID: alarmID)
        let model = try v2Model()
        defer { destroyStore(at: storeURL, model: model) }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let options: [String: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: false,
            NSInferMappingModelAutomaticallyOption: false
        ]
        _ = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options
        )
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        // A main-queue context off the main actor: assert outside the closure, where the
        // issue reaches this test.
        let fetched = try context.performAndWait {
            // KVC, not AlarmConfiguration: the neutralized v2 model hands back NSManagedObject.
            let request = NSFetchRequest<NSManagedObject>(entityName: "AlarmConfiguration")
            request.predicate = NSPredicate(format: "id == %@", alarmID as CVarArg)
            return try context.fetch(request).first.map {
                (name: $0.value(forKey: "name") as? String,
                 enabled: $0.value(forKey: "enabled") as? Bool,
                 smartWakeEnabled: $0.value(forKey: "smartWakeEnabled") as? Bool,
                 smartWakeWindow: $0.value(forKey: "smartWakeWindow") as? Int16)
            }
        }
        let alarm = try #require(fetched, "Alarm created under v1 must be readable under v2")
        #expect(alarm.name == "Migration fixture")
        #expect(alarm.enabled == true)
        #expect(alarm.smartWakeEnabled == true)
        #expect(alarm.smartWakeWindow == 15)
    }

    @Test func migrateStorePreservesAlarmDataAcrossV1ToV2Hop() throws {
        let alarmID = UUID()
        let sourceURL = try makeV1Store(alarmID: alarmID)
        let destinationURL = temporaryStoreURL()
        let model = try currentModel()
        defer {
            destroyStore(at: sourceURL, model: model)
            destroyStore(at: destinationURL, model: model)
            // migrateStore leaves a safety backup next to the source; clean it up.
            let dir = sourceURL.deletingLastPathComponent()
            if let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                for name in names where name.hasPrefix(sourceURL.lastPathComponent + ".migration-backup") {
                    try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
                }
            }
        }

        try CoreDataMigrationManager.shared.migrateStore(from: sourceURL, to: destinationURL)

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _ = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: destinationURL, options: nil
        )
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        // A main-queue context off the main actor: assert outside the closure, where the
        // issue reaches this test.
        let fetched = try context.performAndWait {
            let request = NSFetchRequest<AlarmConfiguration>(entityName: "AlarmConfiguration")
            request.predicate = NSPredicate(format: "id == %@", alarmID as CVarArg)
            return try context.fetch(request).first.map {
                (name: $0.name, enabled: $0.enabled,
                 smartWakeEnabled: $0.smartWakeEnabled, smartWakeWindow: $0.smartWakeWindow)
            }
        }
        let alarm = try #require(fetched, "Alarm created under v1 must survive migration to v2")
        #expect(alarm.name == "Migration fixture")
        #expect(alarm.enabled == true)
        // Explicitly set values are preserved — the new defaults only apply to new rows.
        #expect(alarm.smartWakeEnabled == true)
        #expect(alarm.smartWakeWindow == 15)
    }

    @Test func newAlarmInV2ModelDefaultsToSmartWakeDisabled() throws {
        let storeURL = temporaryStoreURL()
        let model = try currentModel()
        defer { destroyStore(at: storeURL, model: model) }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        _ = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil
        )
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        // A main-queue context off the main actor: assert outside the closure, where the
        // issue reaches this test.
        let defaults = try context.performAndWait { () -> (smartWakeEnabled: Bool, smartWakeWindow: Int16)? in
            guard let alarm = NSEntityDescription.insertNewObject(
                forEntityName: "AlarmConfiguration", into: context
            ) as? AlarmConfiguration else { return nil }
            alarm.id = UUID()
            alarm.name = "Defaults fixture"
            alarm.time = Date()
            try context.save()
            return (alarm.smartWakeEnabled, alarm.smartWakeWindow)
        }
        let alarm = try #require(defaults)

        #expect(alarm.smartWakeEnabled == false,
                "v2 model default for smartWakeEnabled must be NO")
        #expect(alarm.smartWakeWindow == 30,
                "v2 model default for smartWakeWindow must be 30")
    }
}
