import CoreData
import Foundation
import os.log

final class CoreDataMigrationManager {
    static let shared = CoreDataMigrationManager()
    
    private let modelName = "Zeez"
    private let logger = ZeezLogger.coreData
    
    private init() {}
    
    // MARK: - Migration Coordination
    
    func requiresMigration(from sourceURL: URL) -> Bool {
        guard let sourceMetadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: sourceURL,
            options: nil
        ) else {
            // Log file names only — full container paths stay out of public release logs.
            ZeezLogger.error(logger, "Could not read metadata from store: \(sourceURL.lastPathComponent)")
            return false
        }
        
        let currentModel = self.currentModel()
        let isCompatible = currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: sourceMetadata)
        
        let versionInfo = sourceMetadata[NSStoreModelVersionIdentifiersKey] ?? "unknown"
        ZeezLogger.info(logger, "Migration compatibility check - compatible: \(isCompatible), version: \(versionInfo)")
        
        return !isCompatible
    }
    
    func migrateStore(from sourceURL: URL, to destinationURL: URL) throws {
        // Surface a typed error instead of letting the backup-copy step throw
        // NSCocoaErrorDomain 260 for a nonexistent source (2.4).
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw CoreDataMigrationError.storeNotFound(sourceURL)
        }

        ZeezLogger.info(logger, "Starting Core Data migration from \(sourceURL.lastPathComponent) to \(destinationURL.lastPathComponent)")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create backup before migration
        let backupURL = try createMigrationBackup(from: sourceURL)
        
        do {
            // Attempt migration
            try performMigration(from: sourceURL, to: destinationURL)
            
            let migrationTime = CFAbsoluteTimeGetCurrent() - startTime
            ZeezLogger.info(logger, "Migration completed successfully in \(String(format: "%.3f", migrationTime))s - backup at \(backupURL.lastPathComponent)")
            
            // Clean up backup after successful migration (optional - keep for safety)
            // try? FileManager.default.removeItem(at: backupURL)
            
        } catch {
            ZeezLogger.error(logger, "Migration failed, attempting recovery", error: error)
            
            // Attempt to restore from backup
            try restoreFromBackup(backupURL: backupURL, originalURL: sourceURL)
            
            throw CoreDataMigrationError.migrationFailed(underlying: error)
        }
    }
    
    // MARK: - Migration Implementation
    
    private func performMigration(from sourceURL: URL, to destinationURL: URL) throws {
        guard let sourceMetadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: sourceURL,
            options: nil
        ) else {
            throw CoreDataMigrationError.cannotReadMetadata
        }
        
        let migrationSteps = self.migrationSteps(for: sourceMetadata)
        
        if migrationSteps.isEmpty {
            // Try lightweight migration as fallback
            try performLightweightMigration(from: sourceURL, to: destinationURL)
        } else {
            // Perform progressive migration
            try performProgressiveMigration(steps: migrationSteps, from: sourceURL, to: destinationURL)
        }
    }
    
    private func performLightweightMigration(from sourceURL: URL, to destinationURL: URL) throws {
        ZeezLogger.info(logger, "Attempting lightweight migration")
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel())
        
        let options: [String: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            NSPersistentHistoryTrackingKey: true
        ]
        
        // Add source store
        let sourceStore = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: sourceURL,
            options: options
        )
        
        // Migrate to destination
        _ = try coordinator.migratePersistentStore(
            sourceStore,
            to: destinationURL,
            options: options,
            withType: NSSQLiteStoreType
        )
        
        ZeezLogger.info(logger, "Lightweight migration completed successfully")
    }
    
    private func performProgressiveMigration(steps: [MigrationStep], from sourceURL: URL, to destinationURL: URL) throws {
        ZeezLogger.info(logger, "Performing progressive migration with \(steps.count) steps")
        
        var currentURL = sourceURL
        
        for (index, step) in steps.enumerated() {
            ZeezLogger.info(logger, "Executing migration step \(index + 1)/\(steps.count) from \(step.sourceVersion) to \(step.destinationVersion)")
            
            let stepStartTime = CFAbsoluteTimeGetCurrent()
            let isLastStep = index == steps.count - 1
            let stepDestinationURL = isLastStep ? destinationURL : temporaryURL(for: step)
            
            try executeMigrationStep(step: step, from: currentURL, to: stepDestinationURL)
            
            let stepTime = CFAbsoluteTimeGetCurrent() - stepStartTime
            ZeezLogger.info(logger, "Migration step \(index + 1)/\(steps.count) completed in \(String(format: "%.3f", stepTime))s")
            
            // Clean up intermediate files
            if currentURL != sourceURL {
                try? FileManager.default.removeItem(at: currentURL)
            }
            
            currentURL = stepDestinationURL
        }
    }
    
    private func executeMigrationStep(step: MigrationStep, from sourceURL: URL, to destinationURL: URL) throws {
        let mappingModel = step.mappingModel
        let sourceModel = step.sourceModel
        let destinationModel = step.destinationModel
        
        let manager = NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel)
        
        try manager.migrateStore(
            from: sourceURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: mappingModel,
            toDestinationURL: destinationURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil
        )
    }
    
    // MARK: - Model Management
    
    private func currentModel() -> NSManagedObjectModel {
        // Always the shared instance — a second loaded copy of the current
        // model makes NSManagedObject subclass→entity resolution ambiguous (2.4).
        PersistenceController.model
    }
    
    private func model(for version: String) -> NSManagedObjectModel? {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "momd"),
              let bundleURL = Bundle.main.url(forResource: "\(modelName).momd/\(version)", withExtension: "mom") else {
            return nil
        }
        return NSManagedObjectModel(contentsOf: bundleURL)
    }
    
    // MARK: - Migration Steps Logic
    
    private func migrationSteps(for metadata: [String: Any]) -> [MigrationStep] {
        // For now, return empty array to use lightweight migration
        // In future versions, we'll implement progressive migration steps
        let versionInfo = metadata[NSStoreModelVersionIdentifiersKey] ?? "unknown"
        ZeezLogger.info(logger, "Checking for progressive migration steps - current version: \(versionInfo)")
        
        return []
    }
    
    // MARK: - Backup and Recovery
    
    private func createMigrationBackup(from sourceURL: URL) throws -> URL {
        let backupURL = sourceURL.appendingPathExtension("migration-backup-\(Date().timeIntervalSince1970)")
        
        try FileManager.default.copyItem(at: sourceURL, to: backupURL)
        
        // Also backup associated files
        let shmURL = sourceURL.appendingPathExtension("shm")
        let walURL = sourceURL.appendingPathExtension("wal")
        
        if FileManager.default.fileExists(atPath: shmURL.path) {
            try FileManager.default.copyItem(
                at: shmURL,
                to: backupURL.appendingPathExtension("shm")
            )
        }
        
        if FileManager.default.fileExists(atPath: walURL.path) {
            try FileManager.default.copyItem(
                at: walURL,
                to: backupURL.appendingPathExtension("wal")
            )
        }
        
        ZeezLogger.info(logger, "Migration backup created at \(backupURL.lastPathComponent)")
        return backupURL
    }
    
    private func restoreFromBackup(backupURL: URL, originalURL: URL) throws {
        ZeezLogger.info(logger, "Restoring from backup \(backupURL.lastPathComponent) to \(originalURL.lastPathComponent)")
        
        // Remove corrupted files
        try? FileManager.default.removeItem(at: originalURL)
        try? FileManager.default.removeItem(at: originalURL.appendingPathExtension("shm"))
        try? FileManager.default.removeItem(at: originalURL.appendingPathExtension("wal"))
        
        // Restore from backup
        try FileManager.default.copyItem(at: backupURL, to: originalURL)
        
        let backupShmURL = backupURL.appendingPathExtension("shm")
        let backupWalURL = backupURL.appendingPathExtension("wal")
        
        if FileManager.default.fileExists(atPath: backupShmURL.path) {
            try FileManager.default.copyItem(at: backupShmURL, to: originalURL.appendingPathExtension("shm"))
        }
        
        if FileManager.default.fileExists(atPath: backupWalURL.path) {
            try FileManager.default.copyItem(at: backupWalURL, to: originalURL.appendingPathExtension("wal"))
        }
        
        ZeezLogger.info(logger, "Successfully restored from backup")
    }
    
    // MARK: - Utility Methods
    
    private func temporaryURL(for step: MigrationStep) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "migration-\(step.destinationVersion)-\(UUID().uuidString).sqlite"
        return tempDir.appendingPathComponent(filename)
    }
}

// MARK: - Supporting Types

struct MigrationStep {
    let sourceVersion: String
    let destinationVersion: String
    let sourceModel: NSManagedObjectModel
    let destinationModel: NSManagedObjectModel
    let mappingModel: NSMappingModel
}

enum CoreDataMigrationError: Error, LocalizedError {
    case cannotReadMetadata
    case storeNotFound(URL)
    case migrationFailed(underlying: Error)
    case backupFailed(underlying: Error)
    case restoreFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .cannotReadMetadata:
            return "Cannot read Core Data store metadata"
        case .storeNotFound(let url):
            return "No Core Data store exists at \(url.lastPathComponent)"
        case .migrationFailed(let error):
            return "Core Data migration failed: \(error.localizedDescription)"
        case .backupFailed(let error):
            return "Failed to create migration backup: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Failed to restore from backup: \(error.localizedDescription)"
        }
    }
}