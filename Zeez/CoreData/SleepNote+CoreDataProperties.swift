//
//  SleepNote+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/12/25.
//
//

import Foundation
import CoreData


extension SleepNote {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SleepNote> {
        return NSFetchRequest<SleepNote>(entityName: "SleepNote")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var content: String?
    @NSManaged public var category: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var session: SleepSession?

}

extension SleepNote : Identifiable {

}
