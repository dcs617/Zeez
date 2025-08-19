import Foundation
import CoreData
import os.log

/// Manages analytics tracking throughout the app
class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private let context: NSManagedObjectContext
    private var backgroundContext: NSManagedObjectContext
    
    private init() {
        self.context = PersistenceController.shared.container.viewContext
        self.backgroundContext = PersistenceController.shared.container.newBackgroundContext()
    }
    
    // MARK: - Public Tracking Methods
    
    func trackScreen(_ screen: AppScreen, parameters: [String: Any] = [:]) {
        logEvent(.screen, name: screen.rawValue, parameters: parameters)
    }
    
    func trackSleepMetric(_ metric: SleepMetricEvent) {
        logEvent(.sleepMetric, name: metric.name, parameters: metric.parameters)
    }
    
    func trackFeature(_ feature: FeatureEvent) {
        logEvent(.feature, name: feature.name, parameters: feature.parameters)
    }
    
    func trackError(_ error: AppError, context: String? = nil) {
        var params: [String: Any] = [
            "error_description": error.localizedDescription,
            "error_code": error.code
        ]
        if let context = context {
            params["context"] = context
        }
        logEvent(.error, name: error.name, parameters: params)
    }
    
    func trackPerformance(_ metric: PerformanceMetric) {
        logEvent(.performance, name: metric.name, parameters: [
            "duration": metric.duration,
            "success": metric.success,
            "context": metric.context
        ])
    }
    
    // MARK: - Private Methods
    
    private func logEvent(
        _ category: EventCategory,
        name: String,
        parameters: [String: Any] = [:]
    ) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            
            let event = AnalyticsEvent(context: self.backgroundContext)
            event.id = UUID()
            event.timestamp = Date()
            event.category = category.rawValue
            event.name = name
            
            // Store parameters as JSON data
            if let jsonData = try? JSONSerialization.data(withJSONObject: parameters) {
                event.parameters = jsonData
            }
            
            // Add session context if available
            if let activeSession = try? self.backgroundContext.fetch(SleepSession.fetchRequest())
                .first(where: { $0.isActive }) {
                event.session = activeSession
            }
            
            do {
                try self.backgroundContext.save()
            } catch {
                ZeezLogger.debug(ZeezLogger.analytics, "Failed to save analytics event: \(error.localizedDescription)")
                // Note: Analytics failures shouldn't crash the app
            }
            
            ZeezLogger.debug(ZeezLogger.analytics, "Analytics Event: \(category) - \(name) - \(parameters)")
        }
    }
}

// MARK: - Event Types

enum EventCategory: String {
    case screen = "screen_view"
    case sleepMetric = "sleep_metric"
    case feature = "feature"
    case error = "error"
    case performance = "performance"
}

enum AppScreen: String {
    case dashboard = "dashboard"
    case trends = "trends"
    case settings = "settings"
    case sleepDetail = "sleep_detail"
    case alarmSettings = "alarm_settings"
    case subscription = "subscription"
}

struct SleepMetricEvent {
    let name: String
    let parameters: [String: Any]
    
    static func qualityScore(_ score: Double, context: String) -> SleepMetricEvent {
        SleepMetricEvent(
            name: "quality_score",
            parameters: ["score": score, "context": context]
        )
    }
    
    static func sleepDuration(_ duration: TimeInterval, type: String) -> SleepMetricEvent {
        SleepMetricEvent(
            name: "sleep_duration",
            parameters: ["duration": duration, "type": type]
        )
    }
    
    static func environmentalReading(
        temperature: Double,
        humidity: Double,
        noise: Double,
        light: Double
    ) -> SleepMetricEvent {
        SleepMetricEvent(
            name: "environmental_reading",
            parameters: [
                "temperature": temperature,
                "humidity": humidity,
                "noise": noise,
                "light": light
            ]
        )
    }
}

struct FeatureEvent {
    let name: String
    let parameters: [String: Any]
    
    static func usage(_ feature: PremiumFeature, result: String) -> FeatureEvent {
        FeatureEvent(
            name: "feature_usage",
            parameters: ["feature": feature.rawValue, "result": result]
        )
    }
    
    static func impression(_ feature: PremiumFeature, context: String) -> FeatureEvent {
        FeatureEvent(
            name: "feature_impression",
            parameters: ["feature": feature.rawValue, "context": context]
        )
    }
}

struct PerformanceMetric {
    let name: String
    let duration: TimeInterval
    let success: Bool
    let context: String
    
    static func operation(_ name: String, duration: TimeInterval, success: Bool) -> PerformanceMetric {
        PerformanceMetric(
            name: name,
            duration: duration,
            success: success,
            context: "operation"
        )
    }
    
    static func viewLoad(_ view: String, duration: TimeInterval) -> PerformanceMetric {
        PerformanceMetric(
            name: "view_load",
            duration: duration,
            success: true,
            context: view
        )
    }
}
