import Testing
import CoreData
@testable import Zeez

/// Regression tests for the v2 → v3 model hop (PARKED_CAPABILITIES §8a).
///
/// v3 adds two optional attributes to `SleepStage` — `healthKitSampleUUID` and
/// `sourceBundleIdentifier` — the durable identity of an imported Apple Health sample. It is
/// the store's first structural change, so unlike v1 → v2 a v2 store genuinely needs
/// migrating. Existing rows keep their values and read the new attributes as nil; the importer
/// fills them in the next time it sees the night.
@Suite("Model v2→v3 migration", .serialized)
struct CoreDataModelV3MigrationTests {

    // MARK: - Fixtures

    /// The compiled v2 model, with its subclass claims removed so a second model claiming
    /// `SleepSession` cannot make `+entity` ambiguous for suites running in parallel (2.4).
    private static let neutralizedV2Model: NSManagedObjectModel? = {
        guard let momd = Bundle.main.url(forResource: "Zeez", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: momd.appendingPathComponent("Zeez 2.mom")) else {
            return nil
        }
        model.entities.forEach { $0.managedObjectClassName = "NSManagedObject" }
        return model
    }()

    private let history: [AnyHashable: Any] = [NSPersistentHistoryTrackingKey: true as NSNumber]
    private static let sessionID = UUID()
    private static let nightStart = Date(timeIntervalSince1970: 1_790_895_600)

    private func sandbox() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("V3Migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A store written by a v2 build, opened the way the app opens it: one imported
    /// HealthKit night with two stages.
    private func makeV2Store(at url: URL) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: try #require(Self.neutralizedV2Model))
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
                                                       at: url, options: history)
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            let session = NSEntityDescription.insertNewObject(forEntityName: "SleepSession", into: context)
            session.setValue(Self.sessionID, forKey: "id")
            session.setValue(Self.nightStart, forKey: "startTime")
            session.setValue(Self.nightStart.addingTimeInterval(8 * 3600), forKey: "endTime")
            session.setValue(AppConstants.DataProvenance.healthKitImport, forKey: "deviceIdentifier")
            for (index, type) in ["light", "deep"].enumerated() {
                let stage = NSEntityDescription.insertNewObject(forEntityName: "SleepStage", into: context)
                stage.setValue(UUID(), forKey: "id")
                stage.setValue(type, forKey: "stageType")
                stage.setValue(Self.nightStart.addingTimeInterval(Double(index) * 3600), forKey: "startTime")
                stage.setValue(Self.nightStart.addingTimeInterval(Double(index + 1) * 3600), forKey: "endTime")
                stage.setValue(session, forKey: "session")
            }
            try context.save()
        }
        try coordinator.remove(store)
    }

    /// Open `url` exactly as `PersistenceController` does: `prepareForLoading`, then a
    /// container on the shared current model.
    private func openLikeTheApp(_ url: URL) throws -> NSPersistentContainer {
        let description = NSPersistentStoreDescription(url: url)
        PersistenceController.prepareForLoading(description)
        let container = NSPersistentContainer(name: "Zeez", managedObjectModel: PersistenceController.model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        return container
    }

    private func expectNightIntact(in container: NSPersistentContainer) throws {
        let context = container.newBackgroundContext()
        try context.performAndWait {
            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", Self.sessionID as CVarArg)
            let session = try #require(try context.fetch(request).first, "The v2 night must survive the upgrade")
            #expect(session.startTime == Self.nightStart)
            #expect(session.deviceIdentifier == AppConstants.DataProvenance.healthKitImport)
            let stages = session.sleepStages as? Set<SleepStage> ?? []
            #expect(Set(stages.compactMap(\.stageType)) == ["light", "deep"])
            #expect(stages.allSatisfy { $0.healthKitSampleUUID == nil && $0.sourceBundleIdentifier == nil },
                    "Pre-v3 stages have no recorded identity")
        }
    }

    private func closeStores(of container: NSPersistentContainer) {
        let coordinator = container.persistentStoreCoordinator
        coordinator.persistentStores.forEach { try? coordinator.remove($0) }
    }

    // MARK: - Tests

    @Test func v3IsTheCurrentModelAndAddsSampleIdentity() {
        let stage = PersistenceController.model.entitiesByName["SleepStage"]
        #expect(stage?.attributesByName["healthKitSampleUUID"]?.attributeType == .UUIDAttributeType)
        #expect(stage?.attributesByName["sourceBundleIdentifier"]?.attributeType == .stringAttributeType)
        #expect(PersistenceController.model.versionIdentifiers.contains("3"))
    }

    @Test func v2StoreRequiresMigration() throws {
        let directory = try sandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Zeez.sqlite")
        try makeV2Store(at: storeURL)

        #expect(CoreDataMigrationManager.shared.requiresMigration(from: storeURL))
    }

    @Test func v2StoreOpensUnderV3WithDataIntact() throws {
        let directory = try sandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Zeez.sqlite")
        try makeV2Store(at: storeURL)

        let container = try openLikeTheApp(storeURL)
        defer { closeStores(of: container) }

        try expectNightIntact(in: container)
        #expect(!CoreDataMigrationManager.shared.requiresMigration(from: storeURL),
                "The store must now be stamped with the v3 model")
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("Zeez.sqlite.migration-backup-") && !$0.hasSuffix("-wal") && !$0.hasSuffix("-shm") }
        #expect(backups.count == 1, "A pre-migration backup must be kept")
    }

    /// DEVICE_TEST_RUN T1: the first launch of a v3 build on an install that predates D3a
    /// relocates the v2 store into the App Group, *then* migrates it, in one launch.
    @Test func firstLaunchRelocatesThenMigratesAV2Store() throws {
        let directory = try sandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyURL = directory.appendingPathComponent("AppContainer/Zeez.sqlite")
        let groupURL = directory.appendingPathComponent("AppGroup/Zeez.sqlite")
        try FileManager.default.createDirectory(at: legacyURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try makeV2Store(at: legacyURL)

        #expect(try StoreLocation.relocateStore(from: legacyURL, to: groupURL))
        #expect(CoreDataMigrationManager.shared.requiresMigration(from: groupURL),
                "Relocation copies the store as-is; it is still v2 when it lands")

        let container = try openLikeTheApp(groupURL)
        defer { closeStores(of: container) }

        try expectNightIntact(in: container)
        #expect(!FileManager.default.fileExists(atPath: legacyURL.path))
    }

    @Test func manualFallbackMigratesAV2StoreWithDataIntact() throws {
        let directory = try sandbox()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("Zeez.sqlite")
        let destinationURL = directory.appendingPathComponent("Zeez.sqlite.migrated")
        try makeV2Store(at: sourceURL)

        try CoreDataMigrationManager.shared.migrateStore(from: sourceURL, to: destinationURL)

        let container = NSPersistentContainer(name: "Zeez", managedObjectModel: PersistenceController.model)
        let description = NSPersistentStoreDescription(url: destinationURL)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }
        defer { closeStores(of: container) }

        try expectNightIntact(in: container)
    }

    @Test func newStagesStoreSampleIdentity() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.newBackgroundContext()
        let sampleUUID = UUID()
        try context.performAndWait {
            let stage = SleepStage(context: context)
            stage.id = UUID()
            stage.healthKitSampleUUID = sampleUUID
            stage.sourceBundleIdentifier = "com.apple.health.watch"
            try context.save()
        }
        let fetched = try context.performAndWait {
            let request: NSFetchRequest<SleepStage> = SleepStage.fetchRequest()
            request.predicate = NSPredicate(format: "healthKitSampleUUID == %@", sampleUUID as CVarArg)
            return try context.fetch(request).first?.sourceBundleIdentifier
        }
        #expect(fetched == "com.apple.health.watch")
    }
}
