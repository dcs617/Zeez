import CoreData
import Foundation
import SwiftUI

class SleepDebtAnalyzer {
    static let shared = SleepDebtAnalyzer()
    
    private init() {}
    
    func calculateCurrentDebt(context: NSManagedObjectContext) -> Double {
        let request: NSFetchRequest<DailyMetrics> = DailyMetrics.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyMetrics.date, ascending: false)]
        request.predicate = NSPredicate(
            format: "date >= %@",
            Calendar.current.date(byAdding: .day, value: -30, to: Date())! as NSDate
        )
        
        guard let metrics = try? context.fetch(request) else { return 0 }
        let totalDebt = metrics.reduce(0) { $0 + ($1.sleepDebt) }
        
        return totalDebt
    }
    
    func getAverageSleepTime(forDays days: Int, context: NSManagedObjectContext) -> Double {
        let request: NSFetchRequest<DailyMetrics> = DailyMetrics.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyMetrics.date, ascending: false)]
        request.predicate = NSPredicate(
            format: "date >= %@",
            Calendar.current.date(byAdding: .day, value: -days, to: Date())! as NSDate
        )
        
        guard let metrics = try? context.fetch(request) else { return 0 }
        let totalSleep = metrics.reduce(0) { $0 + $1.totalSleepTime }
        
        return totalSleep / Double(metrics.count)
    }
    
    func getDebtHistory(forDays days: Int, context: NSManagedObjectContext) -> [(Date, Double)] {
        let request: NSFetchRequest<DailyMetrics> = DailyMetrics.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyMetrics.date, ascending: true)]
        request.predicate = NSPredicate(
            format: "date >= %@",
            Calendar.current.date(byAdding: .day, value: -days, to: Date())! as NSDate
        )
        
        guard let metrics = try? context.fetch(request) else { return [] }
        
        return metrics.compactMap { metric in
            guard let date = metric.date else { return nil }
            return (date, metric.sleepDebt)
        }
    }
    
    func calculateRecoveryDays(debtHours: Double) -> Int {
        // Recovery rate assumptions:
        // - Can recover up to 1 hour per night on weekdays
        // - Can recover up to 2 hours per night on weekends
        // This is a simplified model and should be adjusted based on research
        
        var remainingDebt = debtHours
        var days = 0
        
        while remainingDebt > 0 {
            days += 1
            let isWeekend = Calendar.current.isDateInWeekend(
                Date().addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
            )
            remainingDebt -= isWeekend ? 2.0 : 1.0
        }
        
        return days
    }
    
    func getDebtSeverity(debtHours: Double) -> DebtSeverity {
        if debtHours <= 2 {
            return .minimal
        } else if debtHours <= 5 {
            return .moderate
        } else if debtHours <= 10 {
            return .significant
        } else {
            return .severe
        }
    }
    
    func getRecommendedSleepDuration(context: NSManagedObjectContext) -> Double {
        // Get user preferences for target sleep duration
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.fetchLimit = 1
        
        if let preferences = try? context.fetch(request).first,
           preferences.targetSleepDuration > 0 {
            return preferences.targetSleepDuration
        }
        
        // Default to 8 hours if no preference set
        return 8.0
    }
}
