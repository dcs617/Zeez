//
//  SleepFact+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension SleepFact {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SleepFact> {
        return NSFetchRequest<SleepFact>(entityName: "SleepFact")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var source: String?
    @NSManaged public var category: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastShownDate: Date?
    @NSManaged public var timesShown: Int16
    @NSManaged public var viewedBy: NSSet?

}

// MARK: Generated accessors for viewedBy
extension SleepFact {

    @objc(addViewedByObject:)
    @NSManaged public func addToViewedBy(_ value: UserPreferences)

    @objc(removeViewedByObject:)
    @NSManaged public func removeFromViewedBy(_ value: UserPreferences)

    @objc(addViewedBy:)
    @NSManaged public func addToViewedBy(_ values: NSSet)

    @objc(removeViewedBy:)
    @NSManaged public func removeFromViewedBy(_ values: NSSet)

}

extension SleepFact : Identifiable {

}
