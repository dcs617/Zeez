//
//  HeartRateData+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/12/25.
//
//

import Foundation
import CoreData


extension HeartRateData {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HeartRateData> {
        return NSFetchRequest<HeartRateData>(entityName: "HeartRateData")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var value: Double
    @NSManaged public var confidence: Double
    @NSManaged public var samplingRate: Double
    @NSManaged public var deviceType: String?
    @NSManaged public var rawData: Data?
    @NSManaged public var session: SleepSession?

}

extension HeartRateData : Identifiable {

}
