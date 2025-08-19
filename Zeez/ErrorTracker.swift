import Foundation
import CoreData
import os.log

/// Tracks and analyzes app errors
class ErrorTracker {
    static let shared = ErrorTracker()
    
    private let analytics = AnalyticsManager.shared
    private let context: NSManagedObjectContext
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
    }
    
    // MARK: - Error Tracking
    
    func trackError(
        _ error: Error,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let appError: AppError
        
        if let existingAppError = error as? AppError {
            appError = existingAppError
        } else {
            appError = .generic(error)
        }
        
        // Enrich error context
        var errorContext: [String: String] = [
            "file": (file as NSString).lastPathComponent,
            "function": function,
            "line": String(line)
        ]

        if let additionalContext = context {
            errorContext["context"] = additionalContext
        }
        
        // Track in analytics
        analytics.trackError(appError, context: context)
        
        // Log error for debugging
        ZeezLogger.debug(ZeezLogger.error, "Error tracked: \(appError.localizedDescription), Context: \(errorContext)")
        
        // Check error thresholds
        checkErrorThresholds(for: appError.code)
    }
    
    // MARK: - Error Analysis
    
    func errorRate(for code: String, timeWindow: TimeInterval = 3600) -> Double {
        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-timeWindow)
        
        var errorCount = 0
        
        context.performAndWait {
            // Fetch error events from CoreData
            let request = AnalyticsEvent.fetchRequest()
            request.predicate = NSPredicate(
                format: "category == %@ AND timestamp >= %@ AND timestamp <= %@",
                EventCategory.error.rawValue,
                startDate as NSDate,
                endDate as NSDate
            )
            
            errorCount = (try? context.count(for: request)) ?? 0
        }
        
        return Double(errorCount) / (timeWindow / 3600.0) // errors per hour
    }
    
    func mostFrequentErrors(limit: Int = 5) -> [(error: String, count: Int)] {
        var errorCounts: [String: Int] = [:]
        
        context.performAndWait {
            let request = AnalyticsEvent.fetchRequest()
            request.predicate = NSPredicate(
                format: "category == %@",
                EventCategory.error.rawValue
            )
            
            guard let events = try? context.fetch(request) else { return }
            
            // Group errors by code and count occurrences
            for event in events {
                guard let name = event.name else { continue }
                errorCounts[name, default: 0] += 1
            }
        }
        
        // Sort by frequency
        return errorCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
    
    // MARK: - Private Methods
    
    private func checkErrorThresholds(for errorCode: String) {
        let currentRate = errorRate(for: errorCode)
        
        // Alert if error rate exceeds threshold
        if currentRate > 10 { // More than 10 errors per hour
            notifyHighErrorRate(
                code: errorCode,
                rate: currentRate
            )
        }
    }
    
    private func notifyHighErrorRate(code: String, rate: Double) {
        // In a real app, this would send notifications to developers
        ZeezLogger.error(ZeezLogger.error, "High error rate detected - Code: \(code), Rate: \(String(format: "%.1f errors/hour", rate))")
    }
}

// MARK: - Error Convenience Methods

extension ErrorTracker {
    func trackCoreDataError(
        _ error: Error,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let appError = AppError.coreData(error)
        trackError(
            appError,
            context: context,
            file: file,
            function: function,
            line: line
        )
    }
    
    func trackNetworkError(
        _ error: Error,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let appError = AppError.network(error)
        trackError(
            appError,
            context: context,
            file: file,
            function: function,
            line: line
        )
    }
    
    func trackUserError(
        _ message: String,
        context: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let appError = AppError.user(message)
        trackError(
            appError,
            context: context,
            file: file,
            function: function,
            line: line
        )
    }
}
