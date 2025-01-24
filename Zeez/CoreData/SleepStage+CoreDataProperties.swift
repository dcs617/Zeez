//
//  SleepStage+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension SleepStage {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SleepStage> {
        return NSFetchRequest<SleepStage>(entityName: "SleepStage")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var startTime: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var stageType: String?
    @NSManaged public var confidence: Double
    @NSManaged public var duration: Double
    @NSManaged public var session: SleepSession?
    @NSManaged public var featureAccess: FeatureAccessRecord?

}

extension SleepStage : Identifiable {

}
