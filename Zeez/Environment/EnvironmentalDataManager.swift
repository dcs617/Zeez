import CoreData
import SwiftUI
import os.log

class EnvironmentalDataManager {
    static let shared = EnvironmentalDataManager()
    
    private init() {}
    
    func getHistoricalData(for factor: EnvironmentalFactor, days: Int, context: NSManagedObjectContext) -> [(Date, Double)] {
        let request: NSFetchRequest<EnvironmentalReading> = EnvironmentalReading.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EnvironmentalReading.timestamp, ascending: true)]
        request.predicate = NSPredicate(
            format: "timestamp >= %@",
            Calendar.current.date(byAdding: .day, value: -days, to: Date())! as NSDate
        )
        
        guard let results = try? context.fetch(request) else { return [] }
        
        return results.compactMap { reading -> (Date, Double)? in
            guard let timestamp = reading.timestamp else { return nil }
            let value: Double?
            switch factor {
            case .temperature: value = reading.measuredTemperature
            case .light: value = reading.measuredLightLevel
            case .sound: value = reading.measuredNoiseLevel
            }
            return value.map { (timestamp, $0) }
        }
    }
    
}
