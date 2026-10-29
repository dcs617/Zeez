import Foundation
import CoreData
import os.log

/// Handles validation and consistency checks for sleep sessions
final class SleepSessionValidator {
    static let shared = SleepSessionValidator()
    private let persistenceController: PersistenceController

    /// Tests inject an in-memory controller (the overlap check fetches from
    /// it); production uses the shared stack.
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    /// Validates a session as it starts: valid times, and no other session at its start.
    ///
    /// It once also required environmental readings and movement data on the active session,
    /// which a session that has just been created never has, so no recording could start
    /// (found 2026-10-29: `startSession` failed with `.missingSensorData` every time).
    func validateSession(_ session: SleepSession) throws {
        try validateTimes(session)
        try validateOverlap(session)
        try validateDuration(session)
    }

    /// Validates a session as it ends: its times only.
    ///
    /// Ending must not fail for want of data. A check that the readings covered 80% of the
    /// night, or that it lasted 15 minutes, rolled the end back and left the session active,
    /// so it could never be ended and blocked every later start (`validateOverlap`). Short
    /// sessions are discarded by `SleepSessionManager.endSession`, and whether the data
    /// supports an estimate is the analyzer's question, not the save's.
    func validateEnd(_ session: SleepSession) throws {
        try validateTimes(session)
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
    
    /// A session that already has an end must be at least the minimum length.
    private func validateDuration(_ session: SleepSession) throws {
        guard let startTime = session.startTime,
              let endTime = session.endTime else { return }

        if endTime.timeIntervalSince(startTime) < AppConstants.Sleep.minimumSessionDuration {
            throw SessionValidationError.insufficientDuration
        }
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
        }
    }
}
