import CoreData
import Foundation
import os.log

final class SleepMetricsCalculator {
    
    func updateDailyMetrics(for session: SleepSession, in context: NSManagedObjectContext) async throws {
        ZeezLogger.sleepTracking.debug("Updating daily metrics for sleep session")
        let objectID = session.objectID

        try await context.perform {
            guard let localSession = try context.existingObject(with: objectID) as? SleepSession else {
                return
            }
            try Self.performDailyMetricsUpdate(for: localSession, in: context)
        }
    }
    
    private static func performDailyMetricsUpdate(for session: SleepSession, in context: NSManagedObjectContext) throws {
        guard let startTime = session.startTime else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startTime)
        
        let request: NSFetchRequest<DailyMetrics> = DailyMetrics.fetchRequest()
        request.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)
        
        let dailyMetrics = try context.fetch(request).first ?? DailyMetrics(context: context)
        
        if dailyMetrics.id == nil {
            dailyMetrics.id = UUID()
            dailyMetrics.date = startOfDay
            dailyMetrics.createdAt = Date()
        }
        
        dailyMetrics.modifiedAt = Date()
        dailyMetrics.addToSessions(session)
        
        let durationHours = (session.durationForSleepGoalComparison ?? 0) / 3600
        ZeezLogger.sleepTracking.debug("Adding session duration \(String(format: "%.1f", durationHours))h to daily metrics")
        
        try updateTotalSleepTime(for: dailyMetrics)
        try updateAverageHeartRate(for: dailyMetrics)
        try updateSleepDebt(for: dailyMetrics)
        
        try context.save()
    }
    
    private static func updateTotalSleepTime(for metrics: DailyMetrics) throws {
        guard let sessions = metrics.sessions?.allObjects as? [SleepSession] else { return }
        
        let totalTime = sessions.reduce(0.0) { total, session in
            total + (session.durationForSleepGoalComparison ?? 0)
        }
        
        metrics.totalSleepTime = totalTime
    }
    
    private static func updateAverageHeartRate(for metrics: DailyMetrics) throws {
        guard let sessions = metrics.sessions?.allObjects as? [SleepSession] else { return }
        
        var totalHeartRate = 0.0
        var readingCount = 0
        
        for session in sessions {
            guard let heartRateData = session.heartRateData?.allObjects as? [HeartRateData] else { continue }
            
            totalHeartRate += heartRateData.reduce(0.0) { $0 + $1.value }
            readingCount += heartRateData.count
        }
        
        metrics.averageHeartRate = readingCount > 0 ? totalHeartRate / Double(readingCount) : 0
    }
    
    private static func updateSleepDebt(for metrics: DailyMetrics) throws {
        let preferencesRequest: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        
        guard let preferences = try metrics.managedObjectContext?.fetch(preferencesRequest).first,
              preferences.sleepGoalEnabled else { return }
        
        let targetSleep = preferences.targetSleepDuration
        metrics.sleepDebt = max(0, targetSleep - metrics.totalSleepTime)
    }
}
