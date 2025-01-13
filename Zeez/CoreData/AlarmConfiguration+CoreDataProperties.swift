//
//  AlarmConfiguration+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/12/25.
//
//

import Foundation
import CoreData


extension AlarmConfiguration {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AlarmConfiguration> {
        return NSFetchRequest<AlarmConfiguration>(entityName: "AlarmConfiguration")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var enabled: Bool
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var smartWakeEnabled: Bool
    @NSManaged public var smartWakeWindow: Int16
    @NSManaged public var time: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var daysOfWeek: Data?
    @NSManaged public var snoozeEnabled: Bool
    @NSManaged public var snoozeDuration: Int16
    @NSManaged public var vibrationOnly: Bool
    @NSManaged public var preferences: UserPreferences?

}

extension AlarmConfiguration : Identifiable {

}
