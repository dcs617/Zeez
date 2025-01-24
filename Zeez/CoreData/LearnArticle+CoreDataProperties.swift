//
//  LearnArticle+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension LearnArticle {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LearnArticle> {
        return NSFetchRequest<LearnArticle>(entityName: "LearnArticle")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var category: String?
    @NSManaged public var readTimeMinutes: Int16
    @NSManaged public var sortOrder: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var imageAssetName: String?
    @NSManaged public var tags: Data?
    @NSManaged public var userProgress: UserArticleProgress?
    @NSManaged public var relatedChallenges: NSSet?
    @NSManaged public var quiz: Quiz?
    @NSManaged public var references: NSSet?
    @NSManaged public var glossaryTerms: NSSet?
    @NSManaged public var notes: SleepNote?
    @NSManaged public var highlights: NoteHighlight?

}

// MARK: Generated accessors for relatedChallenges
extension LearnArticle {

    @objc(addRelatedChallengesObject:)
    @NSManaged public func addToRelatedChallenges(_ value: LearnChallenge)

    @objc(removeRelatedChallengesObject:)
    @NSManaged public func removeFromRelatedChallenges(_ value: LearnChallenge)

    @objc(addRelatedChallenges:)
    @NSManaged public func addToRelatedChallenges(_ values: NSSet)

    @objc(removeRelatedChallenges:)
    @NSManaged public func removeFromRelatedChallenges(_ values: NSSet)

}

// MARK: Generated accessors for references
extension LearnArticle {

    @objc(addReferencesObject:)
    @NSManaged public func addToReferences(_ value: ScientificReference)

    @objc(removeReferencesObject:)
    @NSManaged public func removeFromReferences(_ value: ScientificReference)

    @objc(addReferences:)
    @NSManaged public func addToReferences(_ values: NSSet)

    @objc(removeReferences:)
    @NSManaged public func removeFromReferences(_ values: NSSet)

}

// MARK: Generated accessors for glossaryTerms
extension LearnArticle {

    @objc(addGlossaryTermsObject:)
    @NSManaged public func addToGlossaryTerms(_ value: GlossaryTerm)

    @objc(removeGlossaryTermsObject:)
    @NSManaged public func removeFromGlossaryTerms(_ value: GlossaryTerm)

    @objc(addGlossaryTerms:)
    @NSManaged public func addToGlossaryTerms(_ values: NSSet)

    @objc(removeGlossaryTerms:)
    @NSManaged public func removeFromGlossaryTerms(_ values: NSSet)

}

extension LearnArticle : Identifiable {

}
