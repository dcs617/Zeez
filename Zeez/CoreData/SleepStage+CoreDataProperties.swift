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
    /// `HKObject.uuid` of the Apple Health sample this stage copies; nil for stages Zeez
    /// inferred itself and for HealthKit stages imported before model v3.
    @NSManaged public var healthKitSampleUUID: UUID?
    /// `HKSource.bundleIdentifier` of whatever wrote that sample (model v3).
    @NSManaged public var sourceBundleIdentifier: String?
    @NSManaged public var session: SleepSession?
    @NSManaged public var featureAccess: FeatureAccessRecord?

}

extension SleepStage : Identifiable {

}
