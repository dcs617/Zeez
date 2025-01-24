//
//  MovementData+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension MovementData {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MovementData> {
        return NSFetchRequest<MovementData>(entityName: "MovementData")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var xAcceleration: Double
    @NSManaged public var yAcceleration: Double
    @NSManaged public var zAcceleration: Double
    @NSManaged public var magnitude: Double
    @NSManaged public var activityLevel: Int16
    @NSManaged public var deviceType: String?
    @NSManaged public var session: SleepSession?

}

extension MovementData : Identifiable {

}
