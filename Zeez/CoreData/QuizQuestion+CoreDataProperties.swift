//
//  QuizQuestion+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension QuizQuestion {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QuizQuestion> {
        return NSFetchRequest<QuizQuestion>(entityName: "QuizQuestion")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var question: String?
    @NSManaged public var explanation: String?
    @NSManaged public var sortOrder: Int16
    @NSManaged public var quiz: Quiz?
    @NSManaged public var answers: NSSet?

}

// MARK: Generated accessors for answers
extension QuizQuestion {

    @objc(addAnswersObject:)
    @NSManaged public func addToAnswers(_ value: QuizAnswer)

    @objc(removeAnswersObject:)
    @NSManaged public func removeFromAnswers(_ value: QuizAnswer)

    @objc(addAnswers:)
    @NSManaged public func addToAnswers(_ values: NSSet)

    @objc(removeAnswers:)
    @NSManaged public func removeFromAnswers(_ values: NSSet)

}

extension QuizQuestion : Identifiable {

}
