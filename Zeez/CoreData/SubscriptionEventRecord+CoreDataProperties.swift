//
//  SubscriptionEventRecord+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension SubscriptionEventRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SubscriptionEventRecord> {
        return NSFetchRequest<SubscriptionEventRecord>(entityName: "SubscriptionEventRecord")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var eventType: String?
    @NSManaged public var tier: String?
    @NSManaged public var isAnnual: Bool
    @NSManaged public var source: String?
    @NSManaged public var cancellationReason: String?
    @NSManaged public var metadata: Data?
    @NSManaged public var userPreferences: UserPreferences?
    @NSManaged public var session: SleepSession?

}

extension SubscriptionEventRecord : Identifiable {

}
