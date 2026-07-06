import CoreData
import Foundation
import os.log

protocol SessionValidator {
    func validateSession(_ sessionInfo: SessionInfo) async throws
}

final class SessionValidationService: SessionValidator {
    
    private static let minimumDuration: TimeInterval = 1800 // 30 minutes
    private static let maximumDuration: TimeInterval = 57600 // 16 hours
    
    func validateSession(_ sessionInfo: SessionInfo) async throws {
        try await validateDuration(sessionInfo)
        try await validateTiming(sessionInfo)
        try await validateDataIntegrity(sessionInfo)
        
        ZeezLogger.sleepTracking.debug("Session \(sessionInfo.id) passed all validation checks")
    }
    
    private func validateDuration(_ sessionInfo: SessionInfo) async throws {
        guard sessionInfo.duration >= Self.minimumDuration else {
            let errorMsg = "Session duration too short: \(String(format: "%.1f", sessionInfo.durationHours)) hours (minimum: 0.5 hours)"
            ZeezLogger.error(ZeezLogger.sleepTracking, errorMsg)
            throw ValidationError.durationTooShort(sessionInfo.durationHours)
        }
        
        guard sessionInfo.duration <= Self.maximumDuration else {
            let errorMsg = "Session duration too long: \(String(format: "%.1f", sessionInfo.durationHours)) hours (maximum: 16 hours)"
            ZeezLogger.error(ZeezLogger.sleepTracking, errorMsg)
            throw ValidationError.durationTooLong(sessionInfo.durationHours)
        }
        
        ZeezLogger.sleepTracking.debug("Duration validation passed: \(String(format: "%.1f", sessionInfo.durationHours)) hours")
    }
    
    private func validateTiming(_ sessionInfo: SessionInfo) async throws {
        guard sessionInfo.startTime <= sessionInfo.endTime else {
            let errorMsg = "Invalid session timing: start time (\(sessionInfo.startTime)) after end time (\(sessionInfo.endTime))"
            ZeezLogger.error(ZeezLogger.sleepTracking, errorMsg)
            throw ValidationError.invalidTiming(sessionInfo.startTime, sessionInfo.endTime)
        }
        
        let now = Date()
        guard sessionInfo.endTime <= now.addingTimeInterval(3600) else { // Allow 1 hour future tolerance
            let errorMsg = "End time too far in future: \(sessionInfo.endTime)"
            ZeezLogger.error(ZeezLogger.sleepTracking, errorMsg)
            throw ValidationError.futureEndTime(sessionInfo.endTime)
        }
        
        ZeezLogger.sleepTracking.debug("Timing validation passed")
    }
    
    private func validateDataIntegrity(_ sessionInfo: SessionInfo) async throws {
        guard let sessionId = sessionInfo.session.id else {
            ZeezLogger.sleepTracking.error("Session missing required ID")
            throw ValidationError.missingSessionID
        }
        
        guard !sessionId.uuidString.isEmpty else {
            ZeezLogger.sleepTracking.error("Session has empty UUID")
            throw ValidationError.invalidSessionID(sessionId.uuidString)
        }
        
        ZeezLogger.sleepTracking.debug("Data integrity validation passed")
    }
}

enum ValidationError: LocalizedError {
    case durationTooShort(Double)
    case durationTooLong(Double)
    case invalidTiming(Date, Date)
    case futureEndTime(Date)
    case missingSessionID
    case invalidSessionID(String)
    
    var errorDescription: String? {
        switch self {
        case .durationTooShort(let hours):
            return "Session duration too short: \(String(format: "%.1f", hours)) hours. Minimum duration is 30 minutes."
        case .durationTooLong(let hours):
            return "Session duration too long: \(String(format: "%.1f", hours)) hours. Maximum duration is 16 hours."
        case .invalidTiming(let start, let end):
            return "Invalid session timing: start time (\(start.formatted())) is after end time (\(end.formatted()))"
        case .futureEndTime(let endTime):
            return "Session end time (\(endTime.formatted())) is too far in the future"
        case .missingSessionID:
            return "Session is missing required ID"
        case .invalidSessionID(let id):
            return "Session has invalid ID: \(id)"
        }
    }
}