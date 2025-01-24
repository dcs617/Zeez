import CoreData
import Foundation

class MovementAnalyzer {
    static let shared = MovementAnalyzer()
    
    private init() {}
    
    func analyzePosition(x: Double, y: Double, z: Double) -> SleepPosition {
        // Convert accelerometer data to position
        // Assuming device is worn on wrist:
        // x: lateral movement (left/right)
        // y: vertical movement (up/down)
        // z: forward/backward movement
        
        if abs(y) > abs(x) && abs(y) > abs(z) {
            // Significant vertical component
            return y > 0 ? .back : .stomach
        } else if abs(x) > abs(z) {
            // Significant lateral component
            return x > 0 ? .rightSide : .leftSide
        } else {
            // Default to back if unclear
            return .back
        }
    }
    
    func getPositionDistribution(context: NSManagedObjectContext) -> [SleepPosition: Double] {
        var distribution: [SleepPosition: Int] = [:]
        
        let request: NSFetchRequest<MovementData> = MovementData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MovementData.timestamp, ascending: true)]
        request.predicate = NSPredicate(
            format: "timestamp >= %@",
            Calendar.current.date(byAdding: .day, value: -7, to: Date())! as NSDate
        )
        
        guard let movements = try? context.fetch(request) else { return [:] }
        
        for movement in movements {
            let position = analyzePosition(
                x: movement.xAcceleration,
                y: movement.yAcceleration,
                z: movement.zAcceleration
            )
            distribution[position, default: 0] += 1
        }
        
        let total = Double(distribution.values.reduce(0, +))
        guard total > 0 else { return [:] }
        
        return distribution.mapValues { Double($0) / total }
    }
    
    func getMostCommonPosition(context: NSManagedObjectContext) -> SleepPosition? {
        let distribution = getPositionDistribution(context: context)
        return distribution.max(by: { $0.value < $1.value })?.key
    }
    
    func getPositionalScore(context: NSManagedObjectContext) -> Int {
        let distribution = getPositionDistribution(context: context)
        
        // Calculate weighted score based on position distribution
        let score = distribution.reduce(into: 0.0) { acc, item in
            acc + (Double(item.key.impactScore) * item.value)
        }
        
        return Int(round(score))
    }
    
    func getMovementIntensity(context: NSManagedObjectContext) -> Double {
        let request: NSFetchRequest<MovementData> = MovementData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MovementData.timestamp, ascending: true)]
        request.predicate = NSPredicate(
            format: "timestamp >= %@",
            Calendar.current.date(byAdding: .hour, value: -8, to: Date())! as NSDate
        )
        
        guard let movements = try? context.fetch(request) else { return 0 }
        
        return movements.reduce(0.0) { acc, movement in
            acc + movement.magnitude
        } / Double(movements.count)
    }
    
    func getPositionTransitions(context: NSManagedObjectContext) -> [(Date, SleepPosition)] {
        let request: NSFetchRequest<MovementData> = MovementData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MovementData.timestamp, ascending: true)]
        request.predicate = NSPredicate(
            format: "timestamp >= %@",
            Calendar.current.date(byAdding: .hour, value: -8, to: Date())! as NSDate
        )
        
        guard let movements = try? context.fetch(request) else { return [] }
        
        var transitions: [(Date, SleepPosition)] = []
        var lastPosition: SleepPosition?
        
        for movement in movements {
            guard let timestamp = movement.timestamp else { continue }
            
            let position = analyzePosition(
                x: movement.xAcceleration,
                y: movement.yAcceleration,
                z: movement.zAcceleration
            )
            
            if position != lastPosition {
                transitions.append((timestamp, position))
                lastPosition = position
            }
        }
        
        return transitions
    }
}
