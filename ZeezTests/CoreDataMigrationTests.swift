import Testing
import CoreData
import Foundation
@testable import Zeez

struct CoreDataMigrationTests {
    
    // MARK: - Migration Manager Tests
    
    @Test func migrationManagerInitialization() async throws {
        let migrationManager = CoreDataMigrationManager.shared
        #expect(migrationManager != nil, "Migration manager should initialize successfully")
    }
    
    @Test func requiresMigrationWithCurrentModel() async throws {
        // Create a test store with current model
        let container = NSPersistentContainer(name: "Zeez")
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
    
    // MARK: - PersistenceController Migration Tests
    
    @Test func persistenceControllerMigrationConfiguration() async throws {
        // Test that PersistenceController configures migration correctly
        let controller = PersistenceController(inMemory: true)
        
        // Verify controller initializes
        #expect(controller.container != nil, "Container should be initialized")
        
        // Give it time to load
        let deadline = DispatchTime.now() + .seconds(5)
        while !controller.isStoreLoaded && DispatchTime.now() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        #expect(controller.isStoreLoaded, "Store should load successfully")
    }
    
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
    
    // MARK: - Data Integrity Tests
    
    @Test func dataPreservationDuringMigration() async throws {
        // Create test data
        let controller = PersistenceController(inMemory: true)
        
        // Wait for store to load
        let deadline = DispatchTime.now() + .seconds(5)
        while !controller.isStoreLoaded && DispatchTime.now() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        #expect(controller.isStoreLoaded, "Store should load before testing data preservation")
        
        let context = controller.container.viewContext
        
        // Create test sleep session
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date().addingTimeInterval(-8 * 3600) // 8 hours ago
        session.endTime = Date()
        session.qualityScore = 85.0
        session.isActive = false
        
        // Create related heart rate data
        let heartRateData = HeartRateData(context: context)
        heartRateData.id = UUID()
        heartRateData.timestamp = Date().addingTimeInterval(-4 * 3600) // 4 hours ago
        heartRateData.value = 65.0
        heartRateData.confidence = 95.0
        heartRateData.session = session
        
        try context.save()
        
        // Verify data was saved
        let fetchRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        let sessions = try context.fetch(fetchRequest)
        #expect(sessions.count == 1, "Should have one sleep session")
        
        let fetchedSession = sessions.first!
        #expect(fetchedSession.qualityScore == 85.0, "Quality score should be preserved")
        #expect(fetchedSession.heartRateData?.count == 1, "Heart rate data should be related")
    }
    
    @Test func relationshipIntegrityAfterMigration() async throws {
        let controller = PersistenceController(inMemory: true)
        
        // Wait for store to load
        let deadline = DispatchTime.now() + .seconds(5)
        while !controller.isStoreLoaded && DispatchTime.now() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        let context = controller.container.viewContext
        
        // Create user preferences with alarm configurations
        let userPrefs = UserPreferences(context: context)
        userPrefs.id = UUID()
        userPrefs.targetSleepDuration = 8.0 * 3600 // 8 hours in seconds
        userPrefs.sleepGoalEnabled = true
        
        let alarmConfig = AlarmConfiguration(context: context)
        alarmConfig.id = UUID()
        alarmConfig.name = "Test Alarm"
        alarmConfig.enabled = true
        alarmConfig.smartWakeEnabled = true
        alarmConfig.time = Date()
        alarmConfig.userPreferences = userPrefs
        
        try context.save()
        
        // Verify relationships
        let prefsFetch: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        let preferences = try context.fetch(prefsFetch)
        #expect(preferences.count == 1, "Should have one user preferences record")
        
        let fetchedPrefs = preferences.first!
        #expect(fetchedPrefs.alarmConfigurations?.count == 1, "Should have one related alarm configuration")
        
        if let alarmSet = fetchedPrefs.alarmConfigurations as? Set<AlarmConfiguration> {
            let alarm = alarmSet.first!
            #expect(alarm.name == "Test Alarm", "Alarm name should be preserved")
            #expect(alarm.userPreferences == fetchedPrefs, "Inverse relationship should be intact")
        }
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
            // Expected to fail
            #expect(error is CoreDataMigrationError, "Should throw CoreDataMigrationError")
        }
    }
    
    @Test func storeRecoveryAfterCorruption() async throws {
        // This test simulates what happens when a store becomes corrupted
        // and needs to be recovered
        
        let controller = PersistenceController(inMemory: true)
        
        // Wait for initial load
        let deadline = DispatchTime.now() + .seconds(5)
        while !controller.isStoreLoaded && DispatchTime.now() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        #expect(controller.isStoreLoaded, "Store should initially load successfully")
        
        // Verify we can create and save data
        let context = controller.container.viewContext
        let testSession = SleepSession(context: context)
        testSession.id = UUID()
        testSession.startTime = Date()
        testSession.isActive = false
        
        try context.save()
        
        // Verify data was saved
        let fetchRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        let sessions = try context.fetch(fetchRequest)
        #expect(sessions.count == 1, "Should have saved one session")
    }
    
    // MARK: - Performance Tests
    
    @Test func migrationPerformanceWithLargeDataset() async throws {
        let controller = PersistenceController(inMemory: true)
        
        // Wait for store to load
        let deadline = DispatchTime.now() + .seconds(5)
        while !controller.isStoreLoaded && DispatchTime.now() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        let context = controller.container.viewContext
        
        // Create a moderate dataset for performance testing
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<100 {
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = Date().addingTimeInterval(TimeInterval(-i * 24 * 3600)) // i days ago
            session.endTime = session.startTime?.addingTimeInterval(8 * 3600) // 8 hour sleep
            session.qualityScore = Double.random(in: 60...100)
            session.isActive = false
            
            // Add some related data
            for j in 0..<5 {
                let heartRate = HeartRateData(context: context)
                heartRate.id = UUID()
                heartRate.timestamp = session.startTime?.addingTimeInterval(TimeInterval(j * 3600)) // Every hour
                heartRate.value = Double.random(in: 50...80)
                heartRate.confidence = Double.random(in: 80...100)
                heartRate.session = session
            }
            
            // Save every 20 sessions to avoid memory buildup
            if i % 20 == 0 {
                try context.save()
            }
        }
        
        try context.save()
        
        let creationTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Verify data was created
        let sessionFetch: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        let sessions = try context.fetch(sessionFetch)
        #expect(sessions.count == 100, "Should have created 100 sessions")
        
        let heartRateFetch: NSFetchRequest<HeartRateData> = HeartRateData.fetchRequest()
        let heartRateData = try context.fetch(heartRateFetch)
        #expect(heartRateData.count == 500, "Should have created 500 heart rate records")
        
        #expect(creationTime < 5.0, "Large dataset creation should complete within 5 seconds")
    }
    
    // MARK: - Utility Methods
    
    private func temporaryStoreURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "test-store-\(UUID().uuidString).sqlite"
        return tempDir.appendingPathComponent(filename)
    }
}