//
//  NoteHighlight+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension NoteHighlight {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NoteHighlight> {
        return NSFetchRequest<NoteHighlight>(entityName: "NoteHighlight")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var color: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var note: SleepNote?
    @NSManaged public var article: LearnArticle?

}

extension NoteHighlight : Identifiable {

}
