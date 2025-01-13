//
//  WeeklyMetrics+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/12/25.
//
//

import Foundation
import CoreData


extension WeeklyMetrics {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeeklyMetrics> {
        return NSFetchRequest<WeeklyMetrics>(entityName: "WeeklyMetrics")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var weekStartDate: Date?
    @NSManaged public var weekEndDate: Date?
    @NSManaged public var averageSleepTime: Double
    @NSManaged public var averageQualityScore: Double
    @NSManaged public var consistencyScore: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var dailyMetrics: NSSet?

}

// MARK: Generated accessors for dailyMetrics
extension WeeklyMetrics {

    @objc(addDailyMetricsObject:)
    @NSManaged public func addToDailyMetrics(_ value: DailyMetrics)

    @objc(removeDailyMetricsObject:)
    @NSManaged public func removeFromDailyMetrics(_ value: DailyMetrics)

    @objc(addDailyMetrics:)
    @NSManaged public func addToDailyMetrics(_ values: NSSet)

    @objc(removeDailyMetrics:)
    @NSManaged public func removeFromDailyMetrics(_ values: NSSet)

}

extension WeeklyMetrics : Identifiable {

}
