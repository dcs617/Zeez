import CoreData
import Foundation
import os.log

class SleepPositionAnalyzer {
    static let shared = SleepPositionAnalyzer()
    
    private init() {}
    
    func analyzeSleepPosition(_ movement: MovementData) -> SleepPosition {
        // Convert accelerometer data to position based on device orientation
        // Assuming device is worn on wrist in standard orientation
        
        let x = movement.xAcceleration
        let y = movement.yAcceleration
        let z = movement.zAcceleration
        
        // Threshold for movement detection
        let threshold = 0.5
        
        // Z-axis provides additional context for position stability
        let stabilityFactor = 1.0 - min(abs(z), 1.0)
        
        // Adjust threshold based on stability (more stable = higher confidence)
        let adjustedThreshold = threshold * (1.0 + stabilityFactor * 0.5)
        
        if abs(y) > adjustedThreshold {
            if y > 0 {
                return .back
            } else {
                return .stomach
            }
        } else if abs(x) > adjustedThreshold {
            if x > 0 {
                return .rightSide
            } else {
                return .leftSide
            }
        }
        
        // Return most recent position if no significant movement (high stability indicates settled position)
        return stabilityFactor > 0.7 ? .back : .unknown
    }
    
    func getPositionDistribution(context: NSManagedObjectContext, days: Int = 7) -> [SleepPosition: Double] {
        var distribution: [SleepPosition: Int] = [:]
        let request: NSFetchRequest<MovementData> = MovementData.fetchRequest()
        
        request.predicate = NSPredicate(
            format: "timestamp >= %@",
            Calendar.current.date(byAdding: .day, value: -days, to: Date())! as NSDate
        )
        
        guard let movements = try? context.fetch(request) else { return [:] }
        
        for movement in movements {
            let position = analyzeSleepPosition(movement)
            distribution[position, default: 0] += 1
        }
        
        let total = Double(distribution.values.reduce(0, +))
        return distribution.mapValues { Double($0) / total }
    }
    
    func getPositionTransitions(context: NSManagedObjectContext, sessionId: NSManagedObjectID? = nil) -> [(Date, SleepPosition)] {
        var predicate: NSPredicate
        
        if let sessionId = sessionId {
            predicate = NSPredicate(format: "session.objectID == %@", sessionId)
        } else {
            predicate = NSPredicate(
                format: "timestamp >= %@",
                Calendar.current.date(byAdding: .day, value: -1, to: Date())! as NSDate
            )
        }
        
        let request: NSFetchRequest<MovementData> = MovementData.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MovementData.timestamp, ascending: true)]
        
        guard let movements = try? context.fetch(request) else { return [] }
        
        var transitions: [(Date, SleepPosition)] = []
        var lastPosition: SleepPosition?
        
        for movement in movements {
            guard let timestamp = movement.timestamp else { continue }
            let position = analyzeSleepPosition(movement)
            
            if position != lastPosition {
                transitions.append((timestamp, position))
                lastPosition = position
            }
        }
        
        return transitions
    }
    
    func getAverageTimeInPosition(_ position: SleepPosition, context: NSManagedObjectContext) -> TimeInterval {
        let transitions = getPositionTransitions(context: context)
        var totalTime: TimeInterval = 0
        var lastTransitionTime: Date?
        var lastPosition: SleepPosition?
        
        for (time, currentPosition) in transitions {
            if let last = lastTransitionTime, let lastPos = lastPosition {
                let duration = time.timeIntervalSince(last)
                if lastPos == position {
                    totalTime += duration
                }
            }
            lastTransitionTime = time
            lastPosition = currentPosition
        }
        
        return totalTime
    }
    
    func getMovementIntensity(context: NSManagedObjectContext, timeframe: TimeInterval = 3600) -> Double {
        let request: NSFetchRequest<MovementData> = MovementData.fetchRequest()
        request.predicate = NSPredicate(
            format: "timestamp >= %@",
            Date().addingTimeInterval(-timeframe) as NSDate
        )
        
        guard let movements = try? context.fetch(request) else { return 0.0 }
        
        let totalMovement = movements.reduce(0.0) { sum, movement in
            let magnitude = sqrt(
                pow(movement.xAcceleration, 2) +
                pow(movement.yAcceleration, 2) +
                pow(movement.zAcceleration, 2)
            )
            return sum + magnitude
        }
        
        return totalMovement / Double(max(movements.count, 1))
    }
    
    func getRecommendedPosition(context: NSManagedObjectContext) -> SleepPosition {
        let distribution = getPositionDistribution(context: context)
        let intensity = getMovementIntensity(context: context)
        
        // If user shows high movement in current position, suggest a change
        if intensity > 1.5 {
            // Find the least used position that's not stomach
            let sortedPositions = distribution.filter { $0.key != .stomach }
                .sorted { $0.value < $1.value }
            
            return sortedPositions.first?.key ?? .back
        }
        
        // If current position is working well, maintain it
        return distribution.max(by: { $0.value < $1.value })?.key ?? .back
    }
    
    func getSleepQualityForPosition(_ position: SleepPosition, context: NSManagedObjectContext) -> Double {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "endTime >= %@",
            Calendar.current.date(byAdding: .day, value: -30, to: Date())! as NSDate
        )
        
        guard let sessions = try? context.fetch(request) else { return 0.0 }
        var totalScore = 0.0
        var sessionCount = 0
        
        for session in sessions {
            let transitions = getPositionTransitions(context: context, sessionId: session.objectID)
            let timeInPosition = transitions.filter { $0.1 == position }
                .count * 5 // Assuming 5-minute sampling
            let totalTime = Double(session.endTime?.timeIntervalSince(session.startTime ?? Date()) ?? 0)
            
            if timeInPosition > Int(totalTime * 0.3) { // If spent >30% time in position
                totalScore += session.qualityScore
                sessionCount += 1
            }
        }
        
        return sessionCount > 0 ? totalScore / Double(sessionCount) : 0.0
    }
}
