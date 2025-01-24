//
//  AlarmConfiguration+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
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
    @NSManaged public var wakeType: String?
    @NSManaged public var timerDuration: Int16
    @NSManaged public var audioCapture: Bool
    @NSManaged public var musicEnabled: Bool
    @NSManaged public var musicSource: String?
    @NSManaged public var musicTrackId: String?
    @NSManaged public var musicVolume: Double
    @NSManaged public var fadeInDuration: Int16
    @NSManaged public var name: String?
    @NSManaged public var watchHaptics: Bool
    @NSManaged public var allowVibrationsWithSound: Bool
    @NSManaged public var snoozeGesture: String?
    @NSManaged public var deactivateGesture: String?
    @NSManaged public var alarmSound: String?
    @NSManaged public var alarmSoundSource: String?
    @NSManaged public var userPreferences: UserPreferences?

}

extension AlarmConfiguration : Identifiable {

}
