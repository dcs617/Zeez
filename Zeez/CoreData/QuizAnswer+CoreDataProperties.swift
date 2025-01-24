//
//  QuizAnswer+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension QuizAnswer {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<QuizAnswer> {
        return NSFetchRequest<QuizAnswer>(entityName: "QuizAnswer")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var isCorrect: Bool
    @NSManaged public var question: QuizQuestion?

}

extension QuizAnswer : Identifiable {

}
