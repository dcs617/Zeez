//
//  SleepQualityScore+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/12/25.
//
//

import Foundation
import CoreData


extension SleepQualityScore {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SleepQualityScore> {
        return NSFetchRequest<SleepQualityScore>(entityName: "SleepQualityScore")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var overallScore: Double
    @NSManaged public var sleepCycleScore: Double
    @NSManaged public var movementScore: Double
    @NSManaged public var environmentalScore: Double
    @NSManaged public var heartRateScore: Double
    @NSManaged public var respiratoryScore: Double
    @NSManaged public var calculationVersion: String?
    @NSManaged public var session: SleepSession?

}

extension SleepQualityScore : Identifiable {

}
