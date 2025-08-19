import CoreData
import SwiftUI
import os.log

class EnvironmentalDataManager {
    static let shared = EnvironmentalDataManager()
    
    private init() {}
    
    func getLatestReadings(context: NSManagedObjectContext) -> [EnvironmentalFactor: Double] {
        var readings: [EnvironmentalFactor: Double] = [:]
        
        let request: NSFetchRequest<EnvironmentalReading> = EnvironmentalReading.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EnvironmentalReading.timestamp, ascending: false)]
        request.fetchLimit = 1
        
        if let latest = try? context.fetch(request).first {
            readings[.temperature] = latest.temperature
            readings[.light] = latest.lightLevel
            readings[.sound] = latest.noiseLevel
        }
        
        return readings
    }
    
    func getAverageReadings(for hours: Int, context: NSManagedObjectContext) -> [EnvironmentalFactor: Double] {
        var readings: [EnvironmentalFactor: Double] = [:]
        
        let request: NSFetchRequest<EnvironmentalReading> = EnvironmentalReading.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EnvironmentalReading.timestamp, ascending: false)]
        request.predicate = NSPredicate(
            format: "timestamp >= %@",
            Date().addingTimeInterval(-Double(hours * 3600)) as NSDate
        )
        
        if let results = try? context.fetch(request) {
            readings[.temperature] = results.reduce(0) { $0 + $1.temperature } / Double(results.count)
            readings[.light] = results.reduce(0) { $0 + $1.lightLevel } / Double(results.count)
            readings[.sound] = results.reduce(0) { $0 + $1.noiseLevel } / Double(results.count)
        }
        
        return readings
    }
    
    func getHistoricalData(for factor: EnvironmentalFactor, days: Int, context: NSManagedObjectContext) -> [(Date, Double)] {
        let request: NSFetchRequest<EnvironmentalReading> = EnvironmentalReading.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EnvironmentalReading.timestamp, ascending: true)]
        request.predicate = NSPredicate(
            format: "timestamp >= %@",
            Calendar.current.date(byAdding: .day, value: -days, to: Date())! as NSDate
        )
        
        guard let results = try? context.fetch(request) else { return [] }
        
        return results.compactMap { reading in
            guard let timestamp = reading.timestamp else { return (Date(), 0) }
            let value: Double
            switch factor {
            case .temperature: value = reading.temperature
            case .light: value = reading.lightLevel
            case .sound: value = reading.noiseLevel
            }
            return (timestamp, value)
        }
    }
    
    func getOptimalityScore(for factor: EnvironmentalFactor, value: Double) -> Double {
        let optimal = factor.optimalRange
        let range = factor.range
        
        if value >= optimal.min && value <= optimal.max {
            return 1.0
        }
        
        // Calculate how far outside optimal range we are
        let distanceFromOptimal: Double
        if value < optimal.min {
            distanceFromOptimal = optimal.min - value
            let totalPossibleDistance = optimal.min - range.min
            return max(0, 1 - (distanceFromOptimal / totalPossibleDistance))
        } else {
            distanceFromOptimal = value - optimal.max
            let totalPossibleDistance = range.max - optimal.max
            return max(0, 1 - (distanceFromOptimal / totalPossibleDistance))
        }
    }
    
    func getRecommendations(for factor: EnvironmentalFactor, value: Double) -> String {
        let optimal = factor.optimalRange
        
        if value >= optimal.min && value <= optimal.max {
            return "Current level is optimal for sleep"
        }
        
        switch factor {
        case .temperature:
            return value < optimal.min ?
                "Consider increasing room temperature or using warmer bedding" :
                "Try cooling the room with ventilation or air conditioning"
            
        case .light:
            return value < optimal.min ?
                "Current light level is good for sleep" :
                "Consider using blackout curtains or a sleep mask"
            
        case .sound:
            return value < optimal.min ?
                "Current noise level is good for sleep" :
                "Consider using earplugs or white noise to mask disruptive sounds"
        }
    }
}
