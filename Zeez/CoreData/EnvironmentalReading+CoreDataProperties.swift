//
//  EnvironmentalReading+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/12/25.
//
//

import Foundation
import CoreData


extension EnvironmentalReading {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<EnvironmentalReading> {
        return NSFetchRequest<EnvironmentalReading>(entityName: "EnvironmentalReading")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var temperature: Double
    @NSManaged public var humidity: Double
    @NSManaged public var lightLevel: Double
    @NSManaged public var noiseLevel: Double
    @NSManaged public var deviceType: String?
    @NSManaged public var session: SleepSession?

}

extension EnvironmentalReading : Identifiable {

}
