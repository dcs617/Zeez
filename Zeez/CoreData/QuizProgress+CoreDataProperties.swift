//
//  QuizProgress+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension QuizProgress {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QuizProgress> {
        return NSFetchRequest<QuizProgress>(entityName: "QuizProgress")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var score: Int16
    @NSManaged public var completedAt: Date?
    @NSManaged public var attemptCount: Int16
    @NSManaged public var isCompleted: Bool
    @NSManaged public var quiz: Quiz?
    @NSManaged public var userPreferences: UserPreferences?

}

extension QuizProgress : Identifiable {

}
