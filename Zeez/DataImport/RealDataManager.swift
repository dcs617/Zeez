import Foundation
import CoreData
import os.log

enum SleepDataSource {
    case healthKit
    case manual
    case mock
}

class RealDataManager {
    static let shared = RealDataManager()
    
    private let persistenceController = PersistenceController.shared

    private init() {}
    
    // MARK: - Data Source Management
    
    func getDataSources() -> [SleepDataSource: (count: Int, lastImport: Date?)] {
        let context = persistenceController.container.viewContext
        var sources: [SleepDataSource: (count: Int, lastImport: Date?)] = [:]
        
        // HealthKit data
        let healthKitSessions = fetchSessions(with: "HealthKit", context: context)
        sources[.healthKit] = (
            count: healthKitSessions.count,
            lastImport: healthKitSessions.compactMap { $0.createdAt }.max()
        )
        
        // Manual/Real data (not mock)
        let realSessions = fetchNonMockSessions(context: context)
        sources[.manual] = (
            count: realSessions.count,
            lastImport: realSessions.compactMap { $0.createdAt }.max()
        )
        
        // Mock data (including legacy "iPhone" sessions)
        let mockSessions = fetchMockSessions(context: context)
        sources[.mock] = (
            count: mockSessions.count,
            lastImport: mockSessions.compactMap { $0.createdAt }.max()
        )
        
        return sources
    }
    
    private func fetchSessions(with deviceIdentifier: String, context: NSManagedObjectContext) -> [SleepSession] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(format: "deviceIdentifier CONTAINS[c] %@", deviceIdentifier)
        
        do {
            return try context.fetch(request)
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to fetch sessions for \(deviceIdentifier): \(error.localizedDescription)")
            return []
        }
    }
    
    private func fetchNonMockSessions(context: NSManagedObjectContext) -> [SleepSession] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(format: "NOT (deviceIdentifier CONTAINS[c] %@) AND deviceIdentifier != nil", AppConstants.DataProvenance.mockMarker)
        
        do {
            return try context.fetch(request)
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to fetch non-mock sessions: \(error.localizedDescription)")
            return []
        }
    }
    
    private func fetchMockSessions(context: NSManagedObjectContext) -> [SleepSession] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(format: "deviceIdentifier CONTAINS[c] %@ OR deviceIdentifier == nil OR deviceIdentifier == %@", AppConstants.DataProvenance.mockMarker, AppConstants.DataProvenance.legacyMockDevice)
        
        do {
            return try context.fetch(request)
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to fetch mock sessions: \(error.localizedDescription)")
            return []
        }
    }
    
    func clearMockData(completion: @escaping (Result<Int, Error>) -> Void) {
        ZeezLogger.info(ZeezLogger.coreData, "Clearing mock data")
        
        let context = persistenceController.container.viewContext
        context.perform {
            // First let's see what sessions exist in total
            let allSessionsRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            do {
                let allSessions = try context.fetch(allSessionsRequest)
                ZeezLogger.debug(ZeezLogger.coreData, "Total sessions in database: \(allSessions.count)")
                for session in allSessions.prefix(5) { // Log first 5
                    ZeezLogger.debug(ZeezLogger.coreData, "Session deviceIdentifier: '\(session.deviceIdentifier ?? "nil")'")
                }
            } catch {
                ZeezLogger.error(ZeezLogger.error, "Failed to fetch all sessions: \(error.localizedDescription)")
            }
            
            let mockSessions = self.fetchMockSessions(context: context)
            let count = mockSessions.count
            ZeezLogger.debug(ZeezLogger.coreData, "Found \(count) mock sessions to delete")
            
            for session in mockSessions {
                context.delete(session)
            }
            
            do {
                try context.save()
                ZeezLogger.info(ZeezLogger.coreData, "Successfully deleted \(count) mock sessions")
                DispatchQueue.main.async {
                    completion(.success(count))
                }
            } catch {
                ZeezLogger.error(ZeezLogger.error, "Failed to delete mock data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func hasRealData() -> Bool {
        let context = persistenceController.container.viewContext
        
        // First, let's check total sessions
        let allRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        do {
            let totalCount = try context.count(for: allRequest)
            ZeezLogger.debug(ZeezLogger.coreData, "Total sleep sessions in database: \(totalCount)")
            
            // Now check for real data sessions
            let realRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            realRequest.predicate = NSPredicate(format: "NOT (deviceIdentifier CONTAINS[c] %@) AND deviceIdentifier != nil", AppConstants.DataProvenance.mockMarker)
            realRequest.fetchLimit = 1
            
            let realCount = try context.count(for: realRequest)
            ZeezLogger.debug(ZeezLogger.coreData, "Found \(realCount) real (non-mock) sleep sessions")
            
            // Also check specifically for HealthKit sessions
            let healthKitRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            healthKitRequest.predicate = NSPredicate(format: "deviceIdentifier CONTAINS[c] %@", AppConstants.DataProvenance.healthKitMarker)
            let healthKitCount = try context.count(for: healthKitRequest)
            ZeezLogger.debug(ZeezLogger.coreData, "Found \(healthKitCount) HealthKit sessions")
            
            return realCount > 0
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to check for real data: \(error.localizedDescription)")
            return false
        }
    }
    
}
