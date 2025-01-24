//
//  FeatureAccessRecord+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension FeatureAccessRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FeatureAccessRecord> {
        return NSFetchRequest<FeatureAccessRecord>(entityName: "FeatureAccessRecord")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var feature: String?
    @NSManaged public var context: String?
    @NSManaged public var userPreferences: UserPreferences?
    @NSManaged public var session: SleepSession?
    @NSManaged public var sleepStage: SleepStage?

}

extension FeatureAccessRecord : Identifiable {

}
