//
//  UserPreferences+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/12/25.
//
//

import Foundation
import CoreData


extension UserPreferences {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserPreferences> {
        return NSFetchRequest<UserPreferences>(entityName: "UserPreferences")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var targetSleepDuration: Double
    @NSManaged public var targetBedtime: Date?
    @NSManaged public var targetWakeTime: Date?
    @NSManaged public var sleepGoalEnabled: Bool
    @NSManaged public var notificationsEnabled: Bool
    @NSManaged public var healthKitSyncEnabled: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var alarmConfigurations: NSSet?

}

// MARK: Generated accessors for alarmConfigurations
extension UserPreferences {

    @objc(addAlarmConfigurationsObject:)
    @NSManaged public func addToAlarmConfigurations(_ value: AlarmConfiguration)

    @objc(removeAlarmConfigurationsObject:)
    @NSManaged public func removeFromAlarmConfigurations(_ value: AlarmConfiguration)

    @objc(addAlarmConfigurations:)
    @NSManaged public func addToAlarmConfigurations(_ values: NSSet)

    @objc(removeAlarmConfigurations:)
    @NSManaged public func removeFromAlarmConfigurations(_ values: NSSet)

}

extension UserPreferences : Identifiable {

}
