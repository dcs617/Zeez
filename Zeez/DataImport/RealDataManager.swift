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

    private let persistenceController: PersistenceController

    /// Tests inject an in-memory controller; production uses `.shared`. Follows the
    /// `SleepAnalyzer`/`SleepSessionManager` pattern rather than reading `.shared`
    /// inside logic that needs to be tested.
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Data Source Management

    /// Provenance buckets, defined once. `clearMockData` shares `mockPredicate`, so what
    /// counts as mock data cannot drift between the Settings count and the delete.
    private static var healthKitPredicate: NSPredicate {
        NSPredicate(format: "deviceIdentifier CONTAINS[c] %@", AppConstants.DataProvenance.healthKitMarker)
    }

    /// The exact complement of `mockPredicate`. It previously omitted the legacy `"iPhone"`
    /// marker, so an early-mock-build session counted as **real** here while `clearMockData`
    /// deleted it as mock — and a store holding nothing but legacy mock data reported
    /// `hasRealData() == true`, putting "Using your real sleep data" in Settings above
    /// fabricated sessions. Both predicates must stay complements.
    private static var nonMockPredicate: NSPredicate {
        NSCompoundPredicate(notPredicateWithSubpredicate: mockPredicate)
    }

    private static var mockPredicate: NSPredicate {
        NSPredicate(format: "deviceIdentifier CONTAINS[c] %@ OR deviceIdentifier == nil OR deviceIdentifier == %@", AppConstants.DataProvenance.mockMarker, AppConstants.DataProvenance.legacyMockDevice)
    }

    func getDataSources() -> [SleepDataSource: (count: Int, lastImport: Date?)] {
        let context = persistenceController.container.viewContext
        return [
            .healthKit: summarize(Self.healthKitPredicate, context: context),
            .manual: summarize(Self.nonMockPredicate, context: context),
            // Mock data, including legacy "iPhone" sessions.
            .mock: summarize(Self.mockPredicate, context: context)
        ]
    }

    /// A bucket's session count and most recent import date, without materializing a
    /// single `SleepSession`.
    ///
    /// This used to fetch every matching session — three full object graphs — purely to
    /// read `.count` and `max(createdAt)`, so opening Settings after a 90-day import
    /// faulted in thousands of rows to display two numbers (C6).
    private func summarize(_ predicate: NSPredicate, context: NSManagedObjectContext) -> (count: Int, lastImport: Date?) {
        let countRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        countRequest.predicate = predicate

        // Newest first. SQLite orders NULLs below every value, so in a descending sort a
        // nil `createdAt` lands last and can never mask a real date.
        let latestRequest = NSFetchRequest<NSDictionary>(entityName: "SleepSession")
        latestRequest.predicate = predicate
        latestRequest.resultType = .dictionaryResultType
        latestRequest.propertiesToFetch = ["createdAt"]
        latestRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        latestRequest.fetchLimit = 1

        do {
            let count = try context.count(for: countRequest)
            let lastImport = try context.fetch(latestRequest).first?["createdAt"] as? Date
            return (count: count, lastImport: lastImport)
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to summarize data source: \(error.localizedDescription)")
            return (count: 0, lastImport: nil)
        }
    }

    /// `clearMockData` deletes these, so it needs the objects rather than a count.
    private func fetchMockSessions(context: NSManagedObjectContext) -> [SleepSession] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = Self.mockPredicate

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

        // Existence check only: `fetchLimit = 1` lets SQLite stop at the first match.
        let realRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        realRequest.predicate = Self.nonMockPredicate
        realRequest.fetchLimit = 1

        do {
            let hasReal = try context.count(for: realRequest) > 0

            // Diagnostic counts scan the whole table, and `ZeezLogger.debug` compiles out
            // of release builds while the queries feeding it would not — so gate them too.
            #if DEBUG
            let allRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            let totalCount = try context.count(for: allRequest)
            let healthKitRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            healthKitRequest.predicate = Self.healthKitPredicate
            let healthKitCount = try context.count(for: healthKitRequest)
            ZeezLogger.debug(ZeezLogger.coreData, "Sessions: \(totalCount) total, \(healthKitCount) from HealthKit; has real data: \(hasReal)")
            #endif

            return hasReal
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to check for real data: \(error.localizedDescription)")
            return false
        }
    }
    
}
