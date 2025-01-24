//
//  AnalyticsEvent+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension AnalyticsEvent {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AnalyticsEvent> {
        return NSFetchRequest<AnalyticsEvent>(entityName: "AnalyticsEvent")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var category: String?
    @NSManaged public var name: String?
    @NSManaged public var parameters: Data?
    @NSManaged public var session: SleepSession?
    @NSManaged public var userPreferences: UserPreferences?

}

extension AnalyticsEvent : Identifiable {

}
