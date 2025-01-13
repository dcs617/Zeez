import Foundation
import CoreData

/// Provides formatted data for statistical visualizations
final class StatsDataProvider {
    static let shared = StatsDataProvider()
    private let persistenceController: PersistenceController
    
    private init() {
        self.persistenceController = .shared
    }
    
    /// Fetches sleep quality data for the specified time range
    func fetchSleepQualityData(for timeRange: SleepStatsRange) async throws -> [(date: Date, quality: Double)] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        
        // Calculate date range based on selected time period
        let endDate = Date()
        let startDate: Date
        switch timeRange {
        case .days:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        case .weeks:
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
        case .months:
            startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate)!
        case .all:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate)!
        }
        
        // Configure fetch request
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND endTime <= %@ AND isActive == NO",
            startDate as NSDate,
            endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: true)]
        
        // Fetch and process data
        let sessions = try context.fetch(request)
        return sessions.compactMap { session -> (date: Date, quality: Double)? in
            guard let startTime = session.startTime else { return nil }
            return (date: startTime, quality: session.qualityScore)
        }
    }
    
    /// Fetches sleep schedule data showing patterns over time
    func fetchSleepScheduleData(for timeRange: SleepStatsRange) async throws -> [(hour: Int, sleepProbability: Double)] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        
        // Set up date range
        let endDate = Date()
        let startDate: Date
        switch timeRange {
        case .days:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        case .weeks:
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
        case .months:
            startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate)!
        case .all:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate)!
        }
        
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND endTime <= %@ AND isActive == NO",
            startDate as NSDate,
            endDate as NSDate
        )
        
        // Fetch sessions and calculate hourly sleep probability
        let sessions = try context.fetch(request)
        var hourlyData: [Int: Int] = [:]
        var totalDays = Set<Date>()
        
        // Process each session
        for session in sessions {
            guard let start = session.startTime,
                  let end = session.endTime else { continue }
            
            // Add to tracked days
            let startDay = Calendar.current.startOfDay(for: start)
            totalDays.insert(startDay)
            
            // Calculate sleep probability for each hour
            var currentHour = start
            while currentHour < end {
                let hour = Calendar.current.component(.hour, from: currentHour)
                hourlyData[hour, default: 0] += 1
                currentHour = Calendar.current.date(byAdding: .hour, value: 1, to: currentHour)!
            }
        }
        
        // Convert counts to probabilities
        let totalDaysCount = Double(totalDays.count)
        return (0...23).map { hour in
            let count = Double(hourlyData[hour] ?? 0)
            let probability = totalDaysCount > 0 ? count / totalDaysCount : 0
            return (hour: hour, sleepProbability: probability)
        }
    }
    
    /// Fetches summary statistics for the selected time range
    func fetchSummaryStats(for timeRange: SleepStatsRange) async throws -> SleepSummaryStats {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        
        let endDate = Date()
        let startDate: Date
        switch timeRange {
        case .days:
            startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        case .weeks:
            startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
        case .months:
            startDate = Calendar.current.date(byAdding: .month, value: -3, to: endDate)!
        case .all:
            startDate = Calendar.current.date(byAdding: .year, value: -1, to: endDate)!
        }
        
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND endTime <= %@ AND isActive == NO",
            startDate as NSDate,
            endDate as NSDate
        )
        
        let sessions = try context.fetch(request)
        
        var totalSleepTime: TimeInterval = 0
        var totalQualityScore: Double = 0
        var sessionsWithScore = 0
        
        for session in sessions {
            if let start = session.startTime,
               let end = session.endTime {
                totalSleepTime += end.timeIntervalSince(start)
            }
            
            if let start = session.startTime {
                totalQualityScore += session.qualityScore
                sessionsWithScore += 1
            }
        }
        
        return SleepSummaryStats(
            averageSleepDuration: totalSleepTime / Double(max(sessions.count, 1)),
            averageQualityScore: totalQualityScore / Double(max(sessionsWithScore, 1)),
            totalSessions: sessions.count
        )
    }
}

/// Summary statistics for sleep data
struct SleepSummaryStats {
    let averageSleepDuration: TimeInterval
    let averageQualityScore: Double
    let totalSessions: Int
}
