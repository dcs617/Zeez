import Foundation
import CoreData

// Simple stub for SleepPositionAnalyzer to maintain Learn module compatibility
// TODO: Remove or simplify when Learn module is refactored
class SleepPositionAnalyzer {
    static let shared = SleepPositionAnalyzer()
    
    private init() {}
    
    func getPositionDistribution(context: NSManagedObjectContext) -> [SleepPosition: Double] {
        // Return mock data for now - Learn module to be simplified later
        return [
            .back: 0.4,
            .leftSide: 0.3,
            .rightSide: 0.2,
            .stomach: 0.1
        ]
    }
    
    func getPositionTransitions(context: NSManagedObjectContext) -> [(Date, SleepPosition)] {
        // Return empty array for now
        return []
    }
    
    func getSleepQualityForPosition(_ position: SleepPosition, context: NSManagedObjectContext) -> Double {
        // Return mock quality scores
        switch position {
        case .back: return 85.0
        case .leftSide: return 80.0
        case .rightSide: return 75.0
        case .stomach: return 60.0
        case .unknown: return 50.0
        }
    }
}