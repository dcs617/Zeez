//
//  RespiratoryData+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/12/25.
//
//

import Foundation
import CoreData


extension RespiratoryData {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RespiratoryData> {
        return NSFetchRequest<RespiratoryData>(entityName: "RespiratoryData")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var respiratoryRate: Double
    @NSManaged public var oxygenSaturation: Double
    @NSManaged public var confidence: Double
    @NSManaged public var deviceType: String?
    @NSManaged public var session: SleepSession?

}

extension RespiratoryData : Identifiable {

}
