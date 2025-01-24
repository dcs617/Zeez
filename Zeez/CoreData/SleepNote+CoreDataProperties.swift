//
//  SleepNote+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
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
    @NSManaged public var title: String?
    @NSManaged public var session: SleepSession?
    @NSManaged public var article: LearnArticle?
    @NSManaged public var highlights: NSSet?
    @NSManaged public var linkedNotes: NSSet?

}

// MARK: Generated accessors for highlights
extension SleepNote {

    @objc(addHighlightsObject:)
    @NSManaged public func addToHighlights(_ value: NoteHighlight)

    @objc(removeHighlightsObject:)
    @NSManaged public func removeFromHighlights(_ value: NoteHighlight)

    @objc(addHighlights:)
    @NSManaged public func addToHighlights(_ values: NSSet)

    @objc(removeHighlights:)
    @NSManaged public func removeFromHighlights(_ values: NSSet)

}

// MARK: Generated accessors for linkedNotes
extension SleepNote {

    @objc(addLinkedNotesObject:)
    @NSManaged public func addToLinkedNotes(_ value: SleepNote)

    @objc(removeLinkedNotesObject:)
    @NSManaged public func removeFromLinkedNotes(_ value: SleepNote)

    @objc(addLinkedNotes:)
    @NSManaged public func addToLinkedNotes(_ values: NSSet)

    @objc(removeLinkedNotes:)
    @NSManaged public func removeFromLinkedNotes(_ values: NSSet)

}

extension SleepNote : Identifiable {

}
