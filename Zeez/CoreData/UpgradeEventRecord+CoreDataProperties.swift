//
//  UpgradeEventRecord+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension UpgradeEventRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UpgradeEventRecord> {
        return NSFetchRequest<UpgradeEventRecord>(entityName: "UpgradeEventRecord")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var eventType: String?
    @NSManaged public var feature: String?
    @NSManaged public var source: String?
    @NSManaged public var viewContext: String?
    @NSManaged public var result: String?
    @NSManaged public var userPreferences: UserPreferences?
    @NSManaged public var session: SleepSession?

}

extension UpgradeEventRecord : Identifiable {

}
