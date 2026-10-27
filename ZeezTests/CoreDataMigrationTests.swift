import Testing
import CoreData
import Foundation
@testable import Zeez

struct CoreDataMigrationTests {
    
    // MARK: - Migration Manager Tests
    
    @Test func requiresMigrationWithCurrentModel() async throws {
        // Create a test store with current model (always the shared instance —
        // duplicate loaded models make +entity resolution ambiguous, 2.4)
        let container = NSPersistentContainer(name: "Zeez", managedObjectModel: PersistenceController.model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        // Load the store
        await withCheckedContinuation { continuation in
            container.loadPersistentStores { _, error in
                #expect(error == nil, "Store should load without errors")
                continuation.resume()
            }
        }
        
        // Create temporary file store for testing
        let tempURL = temporaryStoreURL()
        
        // Add a file-based store
        let fileDescription = NSPersistentStoreDescription(url: tempURL)
        fileDescription.type = NSSQLiteStoreType
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: container.managedObjectModel)
        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: tempURL,
            options: nil
        )
        
        // Test migration requirement
        let migrationManager = CoreDataMigrationManager.shared
        let requiresMigration = migrationManager.requiresMigration(from: tempURL)
        
        #expect(!requiresMigration, "Current model should not require migration")
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    @Test func migrationWithInvalidStore() async throws {
        let migrationManager = CoreDataMigrationManager.shared
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/invalid.sqlite")
        
        let requiresMigration = migrationManager.requiresMigration(from: invalidURL)
        #expect(!requiresMigration, "Invalid store should not require migration")
    }
    
    @Test func migrationBackupCreation() async throws {
        // Create a test store
        let tempURL = temporaryStoreURL()
        let testData = "Test store data".data(using: .utf8)!
        try testData.write(to: tempURL)
        
        // Create test WAL and SHM files
        let walURL = tempURL.appendingPathExtension("wal")
        let shmURL = tempURL.appendingPathExtension("shm")
        try testData.write(to: walURL)
        try testData.write(to: shmURL)
        
        // Test backup creation through migration attempt
        let migrationManager = CoreDataMigrationManager.shared
        let destinationURL = temporaryStoreURL()
        
        do {
            try migrationManager.migrateStore(from: tempURL, to: destinationURL)
        } catch {
            // Expected to fail since we don't have a valid store
            // But backup should have been created
        }
        
        // Check for backup files (they should exist with timestamp extension)
        let parentDir = tempURL.deletingLastPathComponent()
        let backupFiles = try FileManager.default.contentsOfDirectory(at: parentDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.contains("migration-backup") }
        
        #expect(!backupFiles.isEmpty, "Migration backup should have been created")
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
        try? FileManager.default.removeItem(at: walURL)
        try? FileManager.default.removeItem(at: shmURL)
        try? FileManager.default.removeItem(at: destinationURL)
        for backupFile in backupFiles {
            try? FileManager.default.removeItem(at: backupFile)
        }
    }
    
    // MARK: - PersistenceController
    
    @Test func backgroundContextCreation() async throws {
        let controller = PersistenceController(inMemory: true)
        
        // Wait for store to load
        let deadline = DispatchTime.now() + .seconds(5)
        while !controller.isStoreLoaded && DispatchTime.now() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        #expect(controller.isStoreLoaded, "Store should load before testing background context")
        
        let backgroundContext = controller.newBackgroundContext()
        #expect(backgroundContext != nil, "Background context should be created")
        #expect(backgroundContext.concurrencyType == .privateQueueConcurrencyType, "Background context should use private queue")
    }
    
    // MARK: - Error Recovery Tests
    
    @Test func migrationErrorRecovery() async throws {
        let migrationManager = CoreDataMigrationManager.shared

        // Test with completely invalid URLs
        let invalidSource = URL(fileURLWithPath: "/invalid/source.sqlite")
        let invalidDestination = URL(fileURLWithPath: "/invalid/destination.sqlite")

        do {
            try migrationManager.migrateStore(from: invalidSource, to: invalidDestination)
            Issue.record("Migration should have failed with invalid URLs")
        } catch {
            // migrateStore guards a nonexistent source with a typed error
            // (previously NSCocoaErrorDomain 260 leaked from the backup step).
            #expect(error is CoreDataMigrationError, "Should throw CoreDataMigrationError")
            if case CoreDataMigrationError.storeNotFound = error {} else {
                Issue.record("Expected .storeNotFound, got \(error)")
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func temporaryStoreURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "test-store-\(UUID().uuidString).sqlite"
        return tempDir.appendingPathComponent(filename)
    }
}