//
//  ChallengeBadge+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension ChallengeBadge {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChallengeBadge> {
        return NSFetchRequest<ChallengeBadge>(entityName: "ChallengeBadge")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var earnedDate: Date?
    @NSManaged public var progress: Double
    @NSManaged public var isCompleted: Bool
    @NSManaged public var challenge: LearnChallenge?
    @NSManaged public var userPreferences: UserPreferences?

}

extension ChallengeBadge : Identifiable {

}
