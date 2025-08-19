//
//  SleepSession+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension SleepSession {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SleepSession> {
        return NSFetchRequest<SleepSession>(entityName: "SleepSession")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var endTime: Date?
    @NSManaged public var isActive: Bool
    @NSManaged public var startTime: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var deviceIdentifier: String?
    @NSManaged public var qualityScore: Double
    @NSManaged public var userFeedback: NSNumber?
    @NSManaged public var environmentalScore: Double
    @NSManaged public var completedCycles: Int16
    @NSManaged public var cycleConsistency: Double
    @NSManaged public var dailyMetrics: DailyMetrics?
    @NSManaged public var sleepStages: NSSet?
    @NSManaged public var heartRateData: NSSet?
    @NSManaged public var movementData: NSSet?
    @NSManaged public var environmentalReadings: NSSet?
    @NSManaged public var respiratoryData: NSSet?
    @NSManaged public var notes: NSSet?
    @NSManaged public var qualityScores: NSSet?
    @NSManaged public var analyticsEvents: NSSet?
    @NSManaged public var subscriptionEvents: NSSet?
    @NSManaged public var featureAccess: NSSet?
    @NSManaged public var upgradeEvents: NSSet?

}

// MARK: Generated accessors for sleepStages
extension SleepSession {

    @objc(addSleepStagesObject:)
    @NSManaged public func addToSleepStages(_ value: SleepStage)

    @objc(removeSleepStagesObject:)
    @NSManaged public func removeFromSleepStages(_ value: SleepStage)

    @objc(addSleepStages:)
    @NSManaged public func addToSleepStages(_ values: NSSet)

    @objc(removeSleepStages:)
    @NSManaged public func removeFromSleepStages(_ values: NSSet)

}

// MARK: Generated accessors for heartRateData
extension SleepSession {

    @objc(addHeartRateDataObject:)
    @NSManaged public func addToHeartRateData(_ value: HeartRateData)

    @objc(removeHeartRateDataObject:)
    @NSManaged public func removeFromHeartRateData(_ value: HeartRateData)

    @objc(addHeartRateData:)
    @NSManaged public func addToHeartRateData(_ values: NSSet)

    @objc(removeHeartRateData:)
    @NSManaged public func removeFromHeartRateData(_ values: NSSet)

}

// MARK: Generated accessors for movementData
extension SleepSession {

    @objc(addMovementDataObject:)
    @NSManaged public func addToMovementData(_ value: MovementData)

    @objc(removeMovementDataObject:)
    @NSManaged public func removeFromMovementData(_ value: MovementData)

    @objc(addMovementData:)
    @NSManaged public func addToMovementData(_ values: NSSet)

    @objc(removeMovementData:)
    @NSManaged public func removeFromMovementData(_ values: NSSet)

}

// MARK: Generated accessors for environmentalReadings
extension SleepSession {

    @objc(addEnvironmentalReadingsObject:)
    @NSManaged public func addToEnvironmentalReadings(_ value: EnvironmentalReading)

    @objc(removeEnvironmentalReadingsObject:)
    @NSManaged public func removeFromEnvironmentalReadings(_ value: EnvironmentalReading)

    @objc(addEnvironmentalReadings:)
    @NSManaged public func addToEnvironmentalReadings(_ values: NSSet)

    @objc(removeEnvironmentalReadings:)
    @NSManaged public func removeFromEnvironmentalReadings(_ values: NSSet)

}

// MARK: Generated accessors for respiratoryData
extension SleepSession {

    @objc(addRespiratoryDataObject:)
    @NSManaged public func addToRespiratoryData(_ value: RespiratoryData)

    @objc(removeRespiratoryDataObject:)
    @NSManaged public func removeFromRespiratoryData(_ value: RespiratoryData)

    @objc(addRespiratoryData:)
    @NSManaged public func addToRespiratoryData(_ values: NSSet)

    @objc(removeRespiratoryData:)
    @NSManaged public func removeFromRespiratoryData(_ values: NSSet)

}

// MARK: Generated accessors for notes
extension SleepSession {

    @objc(addNotesObject:)
    @NSManaged public func addToNotes(_ value: SleepNote)

    @objc(removeNotesObject:)
    @NSManaged public func removeFromNotes(_ value: SleepNote)

    @objc(addNotes:)
    @NSManaged public func addToNotes(_ values: NSSet)

    @objc(removeNotes:)
    @NSManaged public func removeFromNotes(_ values: NSSet)

}

// MARK: Generated accessors for qualityScores
extension SleepSession {

    @objc(addQualityScoresObject:)
    @NSManaged public func addToQualityScores(_ value: SleepQualityScore)

    @objc(removeQualityScoresObject:)
    @NSManaged public func removeFromQualityScores(_ value: SleepQualityScore)

    @objc(addQualityScores:)
    @NSManaged public func addToQualityScores(_ values: NSSet)

    @objc(removeQualityScores:)
    @NSManaged public func removeFromQualityScores(_ values: NSSet)

}

// MARK: Generated accessors for analyticsEvents
extension SleepSession {

    @objc(addAnalyticsEventsObject:)
    @NSManaged public func addToAnalyticsEvents(_ value: AnalyticsEvent)

    @objc(removeAnalyticsEventsObject:)
    @NSManaged public func removeFromAnalyticsEvents(_ value: AnalyticsEvent)

    @objc(addAnalyticsEvents:)
    @NSManaged public func addToAnalyticsEvents(_ values: NSSet)

    @objc(removeAnalyticsEvents:)
    @NSManaged public func removeFromAnalyticsEvents(_ values: NSSet)

}

// MARK: Generated accessors for subscriptionEvents
extension SleepSession {

    @objc(addSubscriptionEventsObject:)
    @NSManaged public func addToSubscriptionEvents(_ value: SubscriptionEventRecord)

    @objc(removeSubscriptionEventsObject:)
    @NSManaged public func removeFromSubscriptionEvents(_ value: SubscriptionEventRecord)

    @objc(addSubscriptionEvents:)
    @NSManaged public func addToSubscriptionEvents(_ values: NSSet)

    @objc(removeSubscriptionEvents:)
    @NSManaged public func removeFromSubscriptionEvents(_ values: NSSet)

}

// MARK: Generated accessors for featureAccess
extension SleepSession {

    @objc(addFeatureAccessObject:)
    @NSManaged public func addToFeatureAccess(_ value: FeatureAccessRecord)

    @objc(removeFeatureAccessObject:)
    @NSManaged public func removeFromFeatureAccess(_ value: FeatureAccessRecord)

    @objc(addFeatureAccess:)
    @NSManaged public func addToFeatureAccess(_ values: NSSet)

    @objc(removeFeatureAccess:)
    @NSManaged public func removeFromFeatureAccess(_ values: NSSet)

}

// MARK: Generated accessors for upgradeEvents
extension SleepSession {

    @objc(addUpgradeEventsObject:)
    @NSManaged public func addToUpgradeEvents(_ value: UpgradeEventRecord)

    @objc(removeUpgradeEventsObject:)
    @NSManaged public func removeFromUpgradeEvents(_ value: UpgradeEventRecord)

    @objc(addUpgradeEvents:)
    @NSManaged public func addToUpgradeEvents(_ values: NSSet)

    @objc(removeUpgradeEvents:)
    @NSManaged public func removeFromUpgradeEvents(_ values: NSSet)

}

extension SleepSession : Identifiable {

}
