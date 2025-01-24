//
//  Quiz+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension Quiz {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Quiz> {
        return NSFetchRequest<Quiz>(entityName: "Quiz")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var quizDescription: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var passingScore: Int16
    @NSManaged public var isRequired: Bool
    @NSManaged public var sortOrder: Int16
    @NSManaged public var questions: NSSet?
    @NSManaged public var userProgress: QuizProgress?
    @NSManaged public var article: LearnArticle?

}

// MARK: Generated accessors for questions
extension Quiz {

    @objc(addQuestionsObject:)
    @NSManaged public func addToQuestions(_ value: QuizQuestion)

    @objc(removeQuestionsObject:)
    @NSManaged public func removeFromQuestions(_ value: QuizQuestion)

    @objc(addQuestions:)
    @NSManaged public func addToQuestions(_ values: NSSet)

    @objc(removeQuestions:)
    @NSManaged public func removeFromQuestions(_ values: NSSet)

}

extension Quiz : Identifiable {

}
