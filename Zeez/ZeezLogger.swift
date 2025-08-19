import Foundation
import os.log

/// Centralized logging infrastructure for the Zeez app
/// Uses iOS native os_log framework for structured, performant logging
public final class ZeezLogger {
    
    // MARK: - Log Categories
    
    /// Core Data operations and persistence
    public static let coreData = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "CoreData")
    
    /// Sleep tracking and analysis
    public static let sleepTracking = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "SleepTracking")
    
    /// Learning system and content management
    public static let learning = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "Learning")
    
    /// Environmental monitoring
    public static let environment = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "Environment")
    
    /// Alarm and notification system
    public static let alarm = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "Alarm")
    
    /// Background tasks and processing
    public static let background = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "Background")
    
    /// User interface and navigation
    public static let ui = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "UI")
    
    /// Analytics and tracking
    public static let analytics = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "Analytics")
    
    /// Error tracking and crash reporting
    public static let error = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "Error")
    
    /// Network and API operations
    public static let network = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "Network")
    
    /// Mock data generation (debug only)
    public static let mockData = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "MockData")
    
    /// General app lifecycle and system events
    public static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.zeez.app", category: "App")
    
    // MARK: - Convenience Methods
    
    /// Log debug information - only in debug builds
    /// - Parameters:
    ///   - logger: The logger category to use
    ///   - message: The message to log
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    public static func debug(
        _ logger: Logger,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        logger.debug("[\(fileName):\(line)] \(function): \(message)")
        #endif
    }
    
    /// Log informational messages
    /// - Parameters:
    ///   - logger: The logger category to use
    ///   - message: The message to log
    public static func info(_ logger: Logger, _ message: String) {
        logger.info("\(message)")
    }
    
    /// Log error conditions
    /// - Parameters:
    ///   - logger: The logger category to use
    ///   - message: The error message
    ///   - error: Optional Error object for additional context
    public static func error(_ logger: Logger, _ message: String, error: Error? = nil) {
        if let error = error {
            logger.error("\(message): \(error.localizedDescription)")
        } else {
            logger.error("\(message)")
        }
    }
    
    /// Log critical faults that indicate serious problems
    /// - Parameters:
    ///   - logger: The logger category to use
    ///   - message: The fault message
    ///   - error: Optional Error object for additional context
    public static func fault(_ logger: Logger, _ message: String, error: Error? = nil) {
        if let error = error {
            logger.fault("\(message): \(error.localizedDescription)")
        } else {
            logger.fault("\(message)")
        }
    }
    
    // MARK: - Sensitive Data Protection
    
    /// Log a message while ensuring sensitive data is redacted in non-debug builds
    /// - Parameters:
    ///   - logger: The logger category to use
    ///   - message: The message containing potentially sensitive data
    ///   - sensitiveData: The sensitive data to redact in release builds
    public static func debugWithSensitiveData(
        _ logger: Logger,
        _ message: String,
        sensitiveData: String
    ) {
        #if DEBUG
        logger.debug("\(message): \(sensitiveData)")
        #else
        logger.debug("\(message): [REDACTED]")
        #endif
    }
    
    // MARK: - Performance Logging
    
    /// Log performance timing information
    /// - Parameters:
    ///   - logger: The logger category to use
    ///   - operation: Description of the operation
    ///   - duration: Time taken in seconds
    public static func performance(_ logger: Logger, operation: String, duration: TimeInterval) {
        #if DEBUG
        logger.info("Performance: \(operation) took \(String(format: "%.3f", duration))s")
        #endif
    }
}