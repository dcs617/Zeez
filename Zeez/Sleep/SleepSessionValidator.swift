import Foundation
import CoreData
import os.log

/// Handles validation and consistency checks for sleep sessions
final class SleepSessionValidator {
    static let shared = SleepSessionValidator()
    private let persistenceController: PersistenceController
    
    private init() {
        self.persistenceController = .shared
    }
    
    /// Validates a sleep session before saving
    func validateSession(_ session: SleepSession) throws {
        try validateTimes(session)
        try validateSensorData(session)
        try validateOverlap(session)
        try validateDuration(session)
    }
    
    /// Validates session times are logical and within bounds
    private func validateTimes(_ session: SleepSession) throws {
        guard let startTime = session.startTime else {
            throw SessionValidationError.missingStartTime
        }
        
        // Ensure start time isn't in the future
        if startTime > Date() {
            throw SessionValidationError.futureStartTime
        }
        
        // If session has ended, validate end time
        if let endTime = session.endTime {
            if endTime <= startTime {
                throw SessionValidationError.invalidEndTime
            }
            
            // Check if duration is unreasonably long (> 24 hours)
            let duration = endTime.timeIntervalSince(startTime)
            if duration > AppConstants.Sleep.maximumSessionDuration {
                throw SessionValidationError.excessiveDuration
            }
        }
    }
    
    /// Validates required sensor data is present and consistent
    private func validateSensorData(_ session: SleepSession) throws {
        if session.isActive {
            // Check if environmental monitoring is working
            if let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
               readings.isEmpty {
                throw SessionValidationError.missingSensorData
            }
            
            // Check if movement monitoring is working
            if let movements = session.movementData?.allObjects as? [MovementData],
               movements.isEmpty {
                throw SessionValidationError.missingSensorData
            }
        }
    }
    
    /// Checks for overlapping sleep sessions
    private func validateOverlap(_ session: SleepSession) throws {
        guard let startTime = session.startTime,
              let sessionId = session.id else { return }
        
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        
        // Find any sessions that overlap with this one
        request.predicate = NSPredicate(
            format: "id != %@ AND startTime <= %@ AND (endTime >= %@ OR endTime == nil)",
            sessionId as any CVarArg,
            startTime as NSDate,
            startTime as NSDate
        )

        let overlappingSessions = try context.fetch(request)
        if !overlappingSessions.isEmpty {
            throw SessionValidationError.overlappingSession
        }
    }
    
    /// Validates session duration and data consistency
    private func validateDuration(_ session: SleepSession) throws {
        guard let startTime = session.startTime,
              let endTime = session.endTime else { return }
        
        let duration = endTime.timeIntervalSince(startTime)
        
        // Check for minimum duration (15 minutes)
        if duration < 900 {
            throw SessionValidationError.insufficientDuration
        }
        
        // Validate data points match duration
        if let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading] {
            let readingsDuration = calculateDataCoverage(readings.compactMap { $0.timestamp })
            if readingsDuration < duration * 0.8 {  // Allow 20% margin for sensor delays
                throw SessionValidationError.incompleteSensorData
            }
        }
    }
    
    /// Calculates the time span covered by a series of timestamps
    private func calculateDataCoverage(_ timestamps: [Date]) -> TimeInterval {
        guard let first = timestamps.min(),
              let last = timestamps.max() else { return 0 }
        return last.timeIntervalSince(first)
    }
}

/// Errors that can occur during session validation
enum SessionValidationError: LocalizedError {
    case missingStartTime
    case invalidEndTime
    case futureStartTime
    case excessiveDuration
    case insufficientDuration
    case overlappingSession
    case missingSensorData
    case incompleteSensorData
    
    var errorDescription: String? {
        switch self {
        case .missingStartTime:
            return "Session start time is missing"
        case .invalidEndTime:
            return "Session end time must be after start time"
        case .futureStartTime:
            return "Session cannot start in the future"
        case .excessiveDuration:
            return "Session duration exceeds 24 hours"
        case .insufficientDuration:
            return "Session must be at least 15 minutes long"
        case .overlappingSession:
            return "Another sleep session exists during this time"
        case .missingSensorData:
            return "Required sensor data is missing"
        case .incompleteSensorData:
            return "Insufficient sensor data for session duration"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingStartTime:
            return "Please restart the sleep session"
        case .invalidEndTime:
            return "Check the session times and try again"
        case .futureStartTime:
            return "Wait until the scheduled start time"
        case .excessiveDuration:
            return "End the current session and start a new one"
        case .insufficientDuration:
            return "Continue tracking for at least 15 minutes"
        case .overlappingSession:
            return "End or delete the overlapping session first"
        case .missingSensorData:
            return "Check sensor permissions and device connectivity"
        case .incompleteSensorData:
            return "Ensure all sensors are working properly"
        }
    }
}
