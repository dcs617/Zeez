//
//  DailyMetrics+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/12/25.
//
//

import Foundation
import CoreData


extension DailyMetrics {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyMetrics> {
        return NSFetchRequest<DailyMetrics>(entityName: "DailyMetrics")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var date: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var totalSleepTime: Double
    @NSManaged public var id: UUID?
    @NSManaged public var averageHeartRate: Double
    @NSManaged public var averageRespiratoryRate: Double
    @NSManaged public var sleepDebt: Double
    @NSManaged public var sessions: NSSet?
    @NSManaged public var weeklyMetrics: WeeklyMetrics?

}

// MARK: Generated accessors for sessions
extension DailyMetrics {

    @objc(addSessionsObject:)
    @NSManaged public func addToSessions(_ value: SleepSession)

    @objc(removeSessionsObject:)
    @NSManaged public func removeFromSessions(_ value: SleepSession)

    @objc(addSessions:)
    @NSManaged public func addToSessions(_ values: NSSet)

    @objc(removeSessions:)
    @NSManaged public func removeFromSessions(_ values: NSSet)

}

extension DailyMetrics : Identifiable {

}
