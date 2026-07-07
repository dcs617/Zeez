import Foundation
import CoreData
import os.log

enum SleepDataSource {
    case healthKit
    case pillow
    case manual
    case mock
}

class RealDataManager {
    static let shared = RealDataManager()
    
    private let persistenceController = PersistenceController.shared
    private let healthKitImporter = HealthKitDataImporter.shared
    private let pillowImporter = PillowDataImporter.shared
    
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
        
        // Pillow data
        let pillowSessions = fetchSessions(containing: "Pillow", context: context)
        sources[.pillow] = (
            count: pillowSessions.count,
            lastImport: pillowSessions.compactMap { $0.createdAt }.max()
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
    
    private func fetchSessions(containing identifier: String, context: NSManagedObjectContext) -> [SleepSession] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(format: "deviceIdentifier CONTAINS[c] %@", identifier)
        
        do {
            return try context.fetch(request)
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to fetch sessions containing \(identifier): \(error.localizedDescription)")
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
    
    // MARK: - Data Import Coordination
    
    func importAllAvailableData(completion: @escaping (Result<ImportSummary, Error>) -> Void) {
        var summary = ImportSummary()
        let dispatchGroup = DispatchGroup()
        var errors: [Error] = []
        
        // Import HealthKit data (last 90 days)
        dispatchGroup.enter()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        
        healthKitImporter.importSleepData(from: startDate, to: Date()) { result in
            defer { dispatchGroup.leave() }
            
            switch result {
            case .success(let count):
                summary.healthKitSessions = count
                ZeezLogger.info(ZeezLogger.coreData, "Imported \(count) HealthKit sessions")
            case .failure(let error):
                errors.append(error)
                ZeezLogger.error(ZeezLogger.error, "HealthKit import failed: \(error.localizedDescription)")
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if !errors.isEmpty {
                completion(.failure(errors.first!))
            } else {
                summary.totalImported = summary.healthKitSessions + summary.pillowSessions + summary.manualSessions
                completion(.success(summary))
            }
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
    
    func shouldUseMockData() -> Bool {
        // Check user preference first
        let userPrefs = getUserPreferences()
        if let useMock = userPrefs?.useMockData {
            return useMock
        }
        
        // If no preference set, use mock data only if no real data exists
        return !hasRealData()
    }
    
    private func getUserPreferences() -> UserPreferences? {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to fetch user preferences: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Data Quality Analysis
    
    func analyzeDataQuality() -> DataQualityReport {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        
        do {
            let allSessions = try context.fetch(request)
            return DataQualityReport(sessions: allSessions)
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to analyze data quality: \(error.localizedDescription)")
            return DataQualityReport(sessions: [])
        }
    }
}

// MARK: - Supporting Types

struct ImportSummary {
    var healthKitSessions: Int = 0
    var pillowSessions: Int = 0
    var manualSessions: Int = 0
    var totalImported: Int = 0
    
    var hasData: Bool {
        return totalImported > 0
    }
}

struct DataQualityReport {
    let totalSessions: Int
    let sessionsWithHeartRate: Int
    let sessionsWithMovement: Int
    let sessionsWithStages: Int
    let averageQualityScore: Double
    let dateRange: DateInterval?
    let dataGaps: [DateInterval]
    
    init(sessions: [SleepSession]) {
        totalSessions = sessions.count
        
        sessionsWithHeartRate = sessions.filter { 
            ($0.heartRateData?.count ?? 0) > 0 
        }.count
        
        sessionsWithMovement = sessions.filter { 
            ($0.movementData?.count ?? 0) > 0 
        }.count
        
        sessionsWithStages = sessions.filter { 
            ($0.sleepStages?.count ?? 0) > 0 
        }.count
        
        averageQualityScore = sessions.isEmpty ? 0.0 : 
            sessions.map { $0.qualityScore }.reduce(0, +) / Double(sessions.count)
        
        // Calculate date range
        let sortedSessions = sessions.sorted { ($0.startTime ?? Date.distantPast) < ($1.startTime ?? Date.distantPast) }
        if let firstSession = sortedSessions.first?.startTime,
           let lastSession = sortedSessions.last?.endTime {
            dateRange = DateInterval(start: firstSession, end: lastSession)
        } else {
            dateRange = nil
        }
        
        // Identify data gaps (more than 2 days between sessions)
        var gaps: [DateInterval] = []
        for i in 0..<(sortedSessions.count - 1) {
            guard let currentEnd = sortedSessions[i].endTime,
                  let nextStart = sortedSessions[i + 1].startTime else { continue }
            
            let gap = nextStart.timeIntervalSince(currentEnd)
            if gap > 2 * 24 * 3600 { // More than 2 days
                gaps.append(DateInterval(start: currentEnd, end: nextStart))
            }
        }
        dataGaps = gaps
    }
    
    var completenessPercentage: Double {
        guard totalSessions > 0 else { return 0.0 }
        
        let completenessScore = Double(sessionsWithHeartRate + sessionsWithMovement + sessionsWithStages)
        let maxPossibleScore = Double(totalSessions * 3) // 3 types of data per session
        
        return (completenessScore / maxPossibleScore) * 100.0
    }
}

// MARK: - UserPreferences Extension

extension UserPreferences {
    var useMockData: Bool? {
        get {
            // This would need to be added to the Core Data model
            // For now, return nil to indicate no preference set
            return nil
        }
        set {
            // This would need to be implemented when the Core Data model is updated
        }
    }
}